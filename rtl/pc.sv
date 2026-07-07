`default_nettype none
 
module pc (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] next_pc,    // the address to use next cycle
    output logic [31:0] pc_out      // the current instruction address
);
 
    always_ff @(posedge clk) begin
        if (rst)
            pc_out <= 32'd0;        // reset: start at address 0
        else
            pc_out <= next_pc;      // normal: take whatever address is fed in
    end
 
endmodule
 
`default_nettype wire