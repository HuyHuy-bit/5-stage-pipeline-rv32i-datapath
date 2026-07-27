// dcache.sv - blocking data cache, write-through or write-back.
//
// Speaks the word + byte-enable vocabulary that lsu.sv produces, so it never
// has to know about lb/lh/sb/sh. A nonzero byte_en means the access is a store.
//
// WRITE_BACK = 0: write-through, no write-allocate.
//   Every store goes to memory and pays full latency whether or not the line is
//   resident; a store that hits also updates the cached copy so later loads see
//   it. Stores never allocate. Simple, and no line is ever dirty.
//
// WRITE_BACK = 1: write-back, write-allocate.
//   A store that hits updates the line, marks it dirty, and completes in one
//   cycle. A miss allocates, first flushing the victim if it is dirty. Memory
//   sees whole blocks instead of individual stores.
//
// The two share one FSM because the difference is small and localised, and
// because the point of building both is to measure the gap rather than to
// assert which one is better.
`default_nettype none

module dcache #(
    parameter int BYTES       = 1024,
    parameter int BLOCK_WORDS = 4,
    parameter int WAYS        = 1,
    parameter int WRITE_BACK  = 0
) (
    input  var logic        clk,
    input  var logic        rst,

    // CPU side
    input  var logic        req,          // a load or store is presented
    input  var logic [31:0] addr,
    input  var logic [3:0]  byte_en,      // nonzero => store
    input  var logic [31:0] write_word,   // already shifted into its lane
    output var logic [31:0] read_word,
    output var logic        ready,

    // backing memory side
    output var logic [31:0] mem_addr,
    output var logic        mem_req,
    output var logic        mem_burst,
    output var logic [3:0]  mem_byte_en,
    output var logic [31:0] mem_write_word,
    input  var logic [31:0] mem_read_word,
    input  var logic        mem_ready,

    // Debug/maintenance: walk every line and write back the dirty ones, so the
    // backing memory holds architectural state again. Write-back means memory
    // alone is no longer the whole picture - the compliance harness reads its
    // signature straight out of data_mem, and without this it would be reading
    // stale words for every value still sitting dirty in the cache. This is the
    // same operation a fence would need.
    input  var logic        flush_req,
    output var logic        flush_done,

    // Counters are (access, miss), never (access, hit). A hit level is true
    // again the instant a refill lands, so counting it when the pipeline
    // advances scores every miss as a hit; misses have to be counted where the
    // decision is made, not where the access completes.
    output var logic        access,
    output var logic        miss_pulse
);
    localparam int SETS  = BYTES / (BLOCK_WORDS * 4 * WAYS);
    localparam int OFFW  = (BLOCK_WORDS <= 1) ? 1 : $clog2(BLOCK_WORDS);
    localparam int IDXW  = (SETS        <= 1) ? 1 : $clog2(SETS);
    localparam int OFFSH = (BLOCK_WORDS <= 1) ? 0 : OFFW;
    localparam int IDXSH = (SETS        <= 1) ? 0 : IDXW;
    localparam int TAGW  = 32 - 2 - OFFSH - IDXSH;
    localparam int WAYW  = (WAYS <= 1) ? 1 : $clog2(WAYS);
    localparam int FSW   = IDXW + 1;   // must hold SETS itself, not just SETS-1

    localparam logic [1:0] S_IDLE = 2'd0, S_WB = 2'd1, S_FILL = 2'd2, S_FLUSH = 2'd3;

    initial begin
        if (SETS * WAYS * BLOCK_WORDS * 4 != BYTES) begin
            $fatal(1, "dcache: BYTES(%0d) must equal SETS*WAYS*BLOCK_WORDS*4", BYTES);
        end
    end

    logic [31:0]     data [WAYS][SETS][BLOCK_WORDS];
    logic [TAGW-1:0] tag  [WAYS][SETS];
    logic            vld  [WAYS][SETS];
    logic            drty [WAYS][SETS];
    logic [WAYW-1:0] victim[SETS];

    // ---- address split ----
    logic [31:0]     word_addr, blk_addr;
    logic [OFFW-1:0] off;
    logic [IDXW-1:0] idx;
    logic [TAGW-1:0] tg;

    assign word_addr = addr >> 2;
    assign blk_addr  = word_addr >> OFFSH;
    assign off       = (BLOCK_WORDS <= 1) ? '0 : OFFW'(word_addr);
    assign idx       = (SETS        <= 1) ? '0 : IDXW'(blk_addr);
    assign tg        = TAGW'(blk_addr >> IDXSH);

    logic [WAYS-1:0] way_hit;
    for (genvar w = 0; w < WAYS; w++) begin : g_ways
        assign way_hit[w] = vld[w][idx] && (tag[w][idx] == tg);
    end

    logic [WAYW-1:0] hit_way;
    always_comb begin
        hit_way = '0;
        for (int w = 0; w < WAYS; w++) begin
            if (way_hit[w]) hit_way = WAYW'(w);
        end
    end

    logic            is_store, line_present, wt_store;
    assign is_store     = |byte_en;
    assign line_present = |way_hit;
    // A write-through store always goes to memory, resident or not.
    assign wt_store     = (WRITE_BACK == 0) && is_store;

    logic [1:0]      state;
    logic [OFFW-1:0] fill_word, wb_word;
    logic [WAYW-1:0] fill_way;

    // The victim being written back. Held separately from idx/fill_way because
    // a flush walks lines unrelated to whatever address is on the CPU port.
    logic [IDXW-1:0] wb_idx;
    logic [WAYW-1:0] wb_way;
    logic            flushing;      // this writeback belongs to a flush walk
    logic [FSW-1:0]  flush_set;
    logic [WAYW-1:0] flush_way;
    logic            flush_complete;

    assign flush_done = flush_complete;

    // ---- CPU-side responses ----
    assign read_word = data[hit_way][idx][off];
    assign access    = req;

    // One pulse per access that finds its line absent. A write-through store
    // that misses sits in S_IDLE for its whole memory access without ever
    // refilling, so a bare level would count it once per stalled cycle; the
    // `counted` one-shot pins it to the first.
    logic counted;
    assign miss_pulse = req && !line_present && (state == S_IDLE) && !counted;

    always_ff @(posedge clk) begin
        if (rst)                       counted <= 1'b0;
        else if (!req)                 counted <= 1'b0;
        else if (miss_pulse && !ready) counted <= 1'b1;
        else if (ready)                counted <= 1'b0;   // access done, rearm
    end

    // State first: a flush runs with no access outstanding, and the pipeline
    // must be held for its duration rather than told the port is free.
    always_comb begin
        if (state != S_IDLE) ready = 1'b0;
        else if (!req)       ready = 1'b1;
        else if (wt_store)   ready = mem_ready;   // always pays memory
        else                 ready = line_present;
    end

    // ---- memory-side requests ----
    always_comb begin
        mem_req        = 1'b0;
        mem_burst      = 1'b0;
        mem_byte_en    = 4'b0000;
        mem_write_word = 32'd0;
        mem_addr       = addr;

        case (state)
            S_WB: begin   // flush the dirty victim, whole words, block order
                mem_req        = 1'b1;
                mem_burst      = 1'b1;
                mem_byte_en    = 4'b1111;
                mem_write_word = data[wb_way][wb_idx][wb_word];
                mem_addr       = ({{(32-TAGW){1'b0}}, tag[wb_way][wb_idx]} << (IDXSH + OFFSH + 2))
                               | ({{(32-IDXW){1'b0}}, wb_idx} << (OFFSH + 2))
                               | ({{(32-OFFW){1'b0}}, wb_word} << 2);
            end
            S_FILL: begin
                mem_req   = 1'b1;
                mem_burst = 1'b1;
                mem_addr  = (blk_addr << (OFFSH + 2))
                          + ({{(32-OFFW){1'b0}}, fill_word} << 2);
            end
            default: begin
                if (req && wt_store) begin
                    mem_req        = 1'b1;
                    mem_byte_en    = byte_en;
                    mem_write_word = write_word;
                    mem_addr       = addr;
                end
            end
        endcase
    end

    // ---- state ----
    always_ff @(posedge clk) begin
        if (rst) begin
            state          <= S_IDLE;
            fill_word      <= '0;
            wb_word        <= '0;
            fill_way       <= '0;
            wb_idx         <= '0;
            wb_way         <= '0;
            flushing       <= 1'b0;
            flush_set      <= '0;
            flush_way      <= '0;
            flush_complete <= 1'b0;
            for (int w = 0; w < WAYS; w++) begin
                for (int s = 0; s < SETS; s++) begin
                    vld[w][s]  <= 1'b0;
                    drty[w][s] <= 1'b0;
                    tag[w][s]  <= '0;
                end
            end
            for (int s = 0; s < SETS; s++) victim[s] <= '0;
        end else begin
            if (!flush_req) flush_complete <= 1'b0;   // rearm once deasserted

            case (state)
                S_IDLE: begin
                    if (flush_req && !flush_complete) begin
                        flush_set <= '0;
                        flush_way <= '0;
                        state     <= S_FLUSH;
                    end else if (req) begin
                        if (wt_store) begin
                            // Keep a resident copy in step with memory. Gated on
                            // mem_ready so the merge happens once, on the cycle
                            // the write actually commits.
                            if (mem_ready && line_present) begin
                                for (int b = 0; b < 4; b++) begin
                                    if (byte_en[b])
                                        data[hit_way][idx][off][8*b +: 8] <= write_word[8*b +: 8];
                                end
                            end
                        end else if (line_present) begin
                            if (is_store) begin
                                for (int b = 0; b < 4; b++) begin
                                    if (byte_en[b])
                                        data[hit_way][idx][off][8*b +: 8] <= write_word[8*b +: 8];
                                end
                                drty[hit_way][idx] <= 1'b1;
                            end
                        end else begin
                            // Miss: allocate. Loads always allocate; stores only
                            // do in write-back mode (write-allocate), and a
                            // write-through store never reaches this branch.
                            fill_way  <= victim[idx];
                            fill_word <= '0;
                            wb_word   <= '0;
                            wb_idx    <= idx;
                            wb_way    <= victim[idx];
                            flushing  <= 1'b0;
                            if ((WRITE_BACK != 0) && vld[victim[idx]][idx] && drty[victim[idx]][idx])
                                state <= S_WB;
                            else
                                state <= S_FILL;
                        end
                    end
                end

                S_WB: begin
                    if (mem_ready) begin
                        if (wb_word == OFFW'(BLOCK_WORDS - 1)) begin
                            wb_word          <= '0;
                            drty[wb_way][wb_idx] <= 1'b0;   // memory is current again
                            // A miss-driven writeback is followed by the refill
                            // it made room for; a flush-driven one just resumes
                            // the walk.
                            state <= flushing ? S_FLUSH : S_FILL;
                        end else begin
                            wb_word <= wb_word + OFFW'(1);
                        end
                    end
                end

                S_FLUSH: begin
                    if (flush_set == FSW'(SETS)) begin
                        flush_complete <= 1'b1;
                        flushing       <= 1'b0;
                        state          <= S_IDLE;
                    end else if (vld[flush_way][flush_set[IDXW-1:0]]
                              && drty[flush_way][flush_set[IDXW-1:0]]) begin
                        // drty was cleared by the writeback, so returning here
                        // falls through to the advance branch instead of looping.
                        wb_idx   <= flush_set[IDXW-1:0];
                        wb_way   <= flush_way;
                        wb_word  <= '0;
                        flushing <= 1'b1;
                        state    <= S_WB;
                    end else if (flush_way == WAYW'(WAYS - 1)) begin
                        flush_way <= '0;
                        flush_set <= flush_set + FSW'(1);
                    end else begin
                        flush_way <= flush_way + WAYW'(1);
                    end
                end

                default: begin   // S_FILL
                    if (mem_ready) begin
                        data[fill_way][idx][fill_word] <= mem_read_word;
                        if (fill_word == OFFW'(BLOCK_WORDS - 1)) begin
                            // Claim the line only once the block is complete.
                            vld[fill_way][idx]  <= 1'b1;
                            tag[fill_way][idx]  <= tg;
                            drty[fill_way][idx] <= 1'b0;
                            // ponytail: FIFO victim selection, as in icache.
                            victim[idx] <= (WAYS <= 1) ? '0 : victim[idx] + WAYW'(1);
                            state       <= S_IDLE;
                        end else begin
                            fill_word <= fill_word + OFFW'(1);
                        end
                    end
                end
            endcase
        end
    end
endmodule

`default_nettype wire
