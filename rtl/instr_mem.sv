// instr_mem.sv - instruction memory (Harvard). 524288 words (2MB), word-addressed.
//
// The array is combinational; what it costs to read is modelled by mem_timing.
// LATENCY=1 restores the original behaviour exactly (ready every cycle, no
// stall), which is what the directed tests and the compliance suite run under.
`default_nettype none

module instr_mem #(
    parameter int LATENCY = 1
) (
    input  var logic        clk,
    input  var logic        rst,
    input  var logic        req,     // an access is being presented this cycle
    input  var logic        burst,   // requester is walking sequential words
    input  var logic [31:0] addr,
    output var logic [31:0] instr,
    output var logic        ready
);
    logic [31:0] mem [0:524287];
    string mem_file;

    initial begin
        if (!$value$plusargs("MEMFILE=%s", mem_file)) begin
            $fatal(1, "instr_mem: no +MEMFILE=<hexfile> supplied");
        end
        $readmemh(mem_file, mem);
    end

    assign instr = mem[addr[20:2]];

    mem_timing #(.LATENCY(LATENCY)) u_timing (
        .clk(clk), .rst(rst),
        .req(req), .burst(burst), .addr(addr), .ready(ready)
    );
endmodule

`default_nettype wire
