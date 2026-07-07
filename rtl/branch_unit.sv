`default_nettype none

module branch_unit (
    input logic [31:0] rs1,
    input logic [31:0] rs2,
    input logic [2:0] funct3,
    input logic branch,
    output logic pc_sel
);
    logic branch_taken;
    always_comb begin
        case (funct3)
            3'b000: branch_taken = (rs1 == rs2); // BEQ
            3'b001: branch_taken = (rs1 != rs2); // BNE
            3'b100: branch_taken = ($signed(rs1) < $signed(rs2)); // BLT
            3'b101: branch_taken = ($signed(rs1) >= $signed(rs2)); // BGE
            3'b110: branch_taken = (rs1 < rs2); // BLTU
            3'b111: branch_taken = (rs1 >= rs2); // BGEU
            default: branch_taken = 1'b0; // Default case
        endcase
    end
    assign pc_sel = branch & branch_taken;
endmodule

`default_nettype wire