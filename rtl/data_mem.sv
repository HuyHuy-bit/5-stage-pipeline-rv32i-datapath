// data_mem.sv - word-addressed data memory with per-lane write enables.
//
// Deals only in whole words plus byte enables; lsu.sv turns RISC-V load/store
// semantics into that. LATENCY is modelled by mem_timing, as for instr_mem.
`default_nettype none

module data_mem #(
    parameter int LATENCY = 1
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        req,          // this cycle genuinely presents an access
    input  logic        burst,        // requester is walking sequential words
    input  logic [31:0] addr,         // byte address
    input  logic [3:0]  byte_en,      // lanes to write (0 = this is a read)
    input  logic [31:0] write_word,   // already shifted into its lane
    output logic [31:0] read_word,
    output logic        ready
);
    // Word-addressed array; subword access handled via per-byte write strobes.
    logic [31:0] mem_array [0:16383];

    string data_file;
    initial begin
        if ($value$plusargs("DATAFILE=%s", data_file)) begin
            $readmemh(data_file, mem_array);
        end
    end

    logic [13:0] word_idx;
    assign word_idx = addr[15:2];

    mem_timing #(.LATENCY(LATENCY)) u_timing (
        .clk(clk), .rst(rst),
        .req(req), .burst(burst), .addr(addr), .ready(ready)
    );

    // A store commits only on the cycle its access completes, not on every
    // cycle it sits in MEM waiting for the memory to answer.
    logic [3:0] we;
    assign we = byte_en & {4{ready}};

    always_ff @(posedge clk) begin
        if (we[0]) mem_array[word_idx][7:0]   <= write_word[7:0];
        if (we[1]) mem_array[word_idx][15:8]  <= write_word[15:8];
        if (we[2]) mem_array[word_idx][23:16] <= write_word[23:16];
        if (we[3]) mem_array[word_idx][31:24] <= write_word[31:24];
    end

    assign read_word = mem_array[word_idx];
endmodule

`default_nettype wire
