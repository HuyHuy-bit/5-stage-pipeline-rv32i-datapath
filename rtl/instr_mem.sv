// instr_mem.sv - instruction memory (Harvard). 524288 words (2MB), word-addressed.
//
// LATENCY models a slow backing store. LATENCY=1 is the original behaviour:
// combinational read, ready every cycle, no stall. Anything higher makes each
// access take that many cycles, which is what gives a cache something to win
// back - in front of a 1-cycle memory a cache can only ever break even.
`default_nettype none

module instr_mem #(
    parameter int LATENCY = 1
) (
    input  var logic        clk,
    input  var logic        rst,
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

    // An access begins when a fetch address arrives that isn't the one already
    // served, and completes LATENCY cycles later. The CPU freezes while !ready,
    // so addr stays put for the duration and the countdown can't be disturbed.
    //
    // ponytail: re-presenting the identical address is free, which makes this a
    // 1-entry cache. For fetch that only fires on a self-loop (the park loop at
    // the end of a benchmark), so it doesn't distort a measurement. Swap in a
    // real req/ack handshake if that stops being true.
    if (LATENCY <= 1) begin : g_fast
        assign ready = 1'b1;
    end else begin : g_slow
        localparam int CW = $clog2(LATENCY + 1);   // +1: must hold LATENCY-1 without pinning the compare

        logic [CW-1:0] cnt;
        logic [31:0]   served_addr;
        logic          served;

        assign ready = served && (served_addr == addr);

        always_ff @(posedge clk) begin
            if (rst) begin
                served      <= 1'b0;
                served_addr <= 32'd0;
                cnt         <= CW'(LATENCY - 1);
            end else if (!ready) begin
                if (cnt <= CW'(1)) begin
                    served      <= 1'b1;
                    served_addr <= addr;
                    cnt         <= CW'(LATENCY - 1);
                end else begin
                    cnt <= cnt - CW'(1);
                end
            end
        end
    end
endmodule

`default_nettype wire
