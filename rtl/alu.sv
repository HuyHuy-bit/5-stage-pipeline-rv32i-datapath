// alu.sv - arithmetic/logic unit. The op selector comes from control.sv.
`default_nettype none

import rv32i_pkg::*;

module alu (
    input  var logic [31:0] a,       // first operand
    input  var logic [31:0] b,       // second operand (register OR immediate)
    input  var logic [3:0]  alu_op,  // operation selector
    output var logic [31:0] result   // result of the operation
);
    // The 'zero' output was removed - it was never consumed. All branch
    // decisions are made by branch_unit.sv from the raw operands, not from
    // an ALU zero flag, so this port was dead weight.
    logic [4:0] shamt;
    assign shamt = b[4:0];

    always_comb begin
        case (alu_op)
            ALU_OP_ADD:   result = a + b;
            ALU_OP_SUB:   result = a - b;
            ALU_OP_AND:   result = a & b;
            ALU_OP_OR:    result = a | b;
            ALU_OP_XOR:   result = a ^ b;
            ALU_OP_SLT:   result = ($signed(a)   < $signed(b))   ? 32'd1 : 32'd0;
            ALU_OP_SLTU:  result = ($unsigned(a) < $unsigned(b)) ? 32'd1 : 32'd0;
            ALU_OP_SLL:   result = a << shamt;
            ALU_OP_SRL:   result = a >> shamt;
            ALU_OP_SRA:   result = $signed(a) >>> shamt;
            ALU_OP_PASSB: result = b;                            // LUI
            default:      result = 32'd0;
        endcase
    end
endmodule

`default_nettype wire