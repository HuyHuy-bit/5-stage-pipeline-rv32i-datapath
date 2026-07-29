`default_nettype none
 
module pc #(
    // Reset vector. 0 for normal builds; the lockstep flow overrides it so the
    // RTL's PC matches the address Spike's memory map forces programs to link at.
    parameter logic [31:0] RESET_PC = 32'h0
) (
    input  var logic        clk,
    input  var logic        rst,
    input  var logic [31:0] next_pc,    // the address to use next cycle
    output var logic [31:0] pc_out      // the current instruction address
);
 
    always_ff @(posedge clk) begin
        if (rst)
            pc_out <= RESET_PC;     // reset vector (0 unless overridden)
        else
            pc_out <= next_pc;      // normal: take whatever address is fed in
    end
 
endmodule
 
`default_nettype wire
