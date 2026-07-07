// imm_gen.sv - extracts and sign-extends the immediate for each format.
`default_nettype none

import rv32i_pkg::*;

module imm_gen (
    input  var logic [31:0] instr,   // the full 32-bit instruction
    output var logic [31:0] imm      // 32-bit sign-extended immediate
);
    logic [6:0] opcode;
    assign opcode = instr[6:0];

    always_comb begin
        case (opcode)
            OPCODE_I_TYPE, OPCODE_LOAD:
                imm = {{20{instr[31]}}, instr[31:20]};                                        // I-type
            OPCODE_STORE:
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};                           // S-type
            OPCODE_BRANCH:
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}; // B-type
            OPCODE_LUI, OPCODE_AUIPC:
                imm = {instr[31:12], 12'b0};                                                  // U-type
            OPCODE_JAL:
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}; // J-type
            OPCODE_JALR:
                imm = {{20{instr[31]}}, instr[31:20]};                                        // I-type (JALR)
            default:
                imm = 32'd0;
        endcase
    end
endmodule

`default_nettype wire