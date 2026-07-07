// instr_mem.sv - instruction memory (Harvard). 256 words, word-addressed.
`default_nettype none

module instr_mem (
    input  var logic [31:0] addr,
    output var logic [31:0] instr
);
    logic [31:0] mem [0:255];
    string mem_file;

    initial begin
        if (!$value$plusargs("MEMFILE=%s", mem_file)) begin
            $fatal(1, "instr_mem: no +MEMFILE=<hexfile> supplied");
        end
        $readmemh(mem_file, mem);
    end

    assign instr = mem[addr[9:2]];
endmodule

`default_nettype wire