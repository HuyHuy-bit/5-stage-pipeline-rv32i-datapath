// branch_predictor.sv - front-end branch prediction.
`default_nettype none

module branch_predictor #(
    parameter int IDX_BITS = 6,                  // 2^6 = 64 entries
    parameter int TAG_BITS = 8
) (
    input  var logic        clk,
    input  var logic        rst,

    // ---- predict port (IF stage) ----
    input  var logic [31:0] pc_predict,          // current fetch PC
    output var logic        predict_taken,       // 1 => redirect fetch to predict_target
    output var logic [31:0] predict_target,

    // ---- update port (EX stage, when a branch/jump resolves) ----
    input  var logic        update_en,           // this cycle a branch/jump resolved
    input  var logic [31:0] update_pc,           // that instruction's PC
    input  var logic        update_taken,        // was it actually taken?
    input  var logic [31:0] update_target        // its actual target (valid when taken)
);
    localparam int NUM_ENTRIES = (1 << IDX_BITS);

    // index/tag slicing helpers
    function automatic logic [IDX_BITS-1:0] idx_of(input logic [31:0] pc);
        idx_of = pc[IDX_BITS+1:2];               // drop 2 low (word-aligned) bits
    endfunction
    function automatic logic [TAG_BITS-1:0] tag_of(input logic [31:0] pc);
        tag_of = pc[IDX_BITS+1+TAG_BITS : IDX_BITS+2];
    endfunction

    // ---- storage ----
    logic [1:0]          bht      [NUM_ENTRIES];
    logic                btb_valid[NUM_ENTRIES];
    logic [TAG_BITS-1:0] btb_tag  [NUM_ENTRIES];
    logic [31:0]         btb_tgt  [NUM_ENTRIES];

    // ---- predict (combinational read) ----
    logic [IDX_BITS-1:0] p_idx;
    logic [TAG_BITS-1:0] p_tag;
    assign p_idx = idx_of(pc_predict);
    assign p_tag = tag_of(pc_predict);

    logic btb_hit;
    assign btb_hit       = btb_valid[p_idx] && (btb_tag[p_idx] == p_tag);
    assign predict_taken = btb_hit && bht[p_idx][1];   // high counter bit
    assign predict_target = btb_tgt[p_idx];

    // ---- update (synchronous write) ----
    logic [IDX_BITS-1:0] u_idx;
    logic [TAG_BITS-1:0] u_tag;
    assign u_idx = idx_of(update_pc);
    assign u_tag = tag_of(update_pc);

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                bht[i]       <= 2'b01;             // weakly not-taken: neutral-ish start
                btb_valid[i] <= 1'b0;
                btb_tag[i]   <= '0;
                btb_tgt[i]   <= 32'd0;
            end
        end else if (update_en) begin
            // 2-bit saturating counter toward the actual outcome
            if (update_taken) begin
                if (bht[u_idx] != 2'b11) bht[u_idx] <= bht[u_idx] + 2'b01;
                // install/refresh BTB target on a taken branch
                btb_valid[u_idx] <= 1'b1;
                btb_tag[u_idx]   <= u_tag;
                btb_tgt[u_idx]   <= update_target;
            end else begin
                if (bht[u_idx] != 2'b00) bht[u_idx] <= bht[u_idx] - 2'b01;
                // note: we keep the BTB entry on not-taken; the counter alone
                // suppresses the prediction. Evicting on every not-taken would
                // thrash entries for branches that alternate.
            end
        end
    end
endmodule

`default_nettype wire
