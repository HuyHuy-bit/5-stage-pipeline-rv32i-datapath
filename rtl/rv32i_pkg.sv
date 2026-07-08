// rv32i_pkg.sv - shared constants for the RV32I core.
// Previously the opcode encodings were duplicated as localparams in both
// control.sv and imm_gen.sv; a change in one place could silently diverge
// from the other. Centralizing them here means the encoding is defined once.
`default_nettype none

package rv32i_pkg;

    // ---- Opcodes (instr[6:0]) ----
    localparam logic [6:0] OPCODE_R_TYPE = 7'b0110011;
    localparam logic [6:0] OPCODE_I_TYPE = 7'b0010011;
    localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
    localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam logic [6:0] OPCODE_JAL    = 7'b1101111;
    localparam logic [6:0] OPCODE_JALR   = 7'b1100111;
    localparam logic [6:0] OPCODE_LUI    = 7'b0110111;
    localparam logic [6:0] OPCODE_AUIPC  = 7'b0010111;
    localparam logic [6:0] OPCODE_FENCE  = 7'b0001111;

    // ---- ALU operation codes (control.sv -> alu.sv, the alu_op field) ----
    localparam logic [3:0] ALU_OP_ADD  = 4'b0000;
    localparam logic [3:0] ALU_OP_SUB  = 4'b0001;
    localparam logic [3:0] ALU_OP_AND  = 4'b0010;
    localparam logic [3:0] ALU_OP_OR   = 4'b0011;
    localparam logic [3:0] ALU_OP_XOR  = 4'b0100;
    localparam logic [3:0] ALU_OP_SLT  = 4'b0101;
    localparam logic [3:0] ALU_OP_SLTU = 4'b0110;
    localparam logic [3:0] ALU_OP_SLL  = 4'b0111;
    localparam logic [3:0] ALU_OP_SRL  = 4'b1000;
    localparam logic [3:0] ALU_OP_SRA  = 4'b1001;
    localparam logic [3:0] ALU_OP_PASSB = 4'b1010; // pass operand B through (LUI)

    // ---- SYSTEM opcode (CSR instructions, ECALL, EBREAK, MRET) ----
    localparam logic [6:0] OPCODE_SYSTEM = 7'b1110011;

    // funct3 encodings within OPCODE_SYSTEM
    localparam logic [2:0] F3_PRIV   = 3'b000; // ECALL/EBREAK/MRET (distinguished by imm)
    localparam logic [2:0] F3_CSRRW  = 3'b001;
    localparam logic [2:0] F3_CSRRS  = 3'b010;
    localparam logic [2:0] F3_CSRRC  = 3'b011;
    localparam logic [2:0] F3_CSRRWI = 3'b101;
    localparam logic [2:0] F3_CSRRSI = 3'b110;
    localparam logic [2:0] F3_CSRRCI = 3'b111;

    // full-instruction encodings for the privileged ops (F3_PRIV)
    localparam logic [31:0] INSTR_ECALL  = 32'h00000073;
    localparam logic [31:0] INSTR_EBREAK = 32'h00100073;
    localparam logic [31:0] INSTR_MRET   = 32'h30200073;

    // ---- CSR addresses (instr[31:20]) - minimal M-mode set ----
    localparam logic [11:0] CSR_MTVEC = 12'h305;
    localparam logic [11:0] CSR_MEPC  = 12'h341;
    localparam logic [11:0] CSR_MCAUSE = 12'h342;

    // ---- Exception cause codes (mcause, interrupt bit = 0) ----
    localparam logic [31:0] CAUSE_MISALIGNED_FETCH = 32'd0;
    localparam logic [31:0] CAUSE_ILLEGAL_INSTR    = 32'd2;
    localparam logic [31:0] CAUSE_BREAKPOINT       = 32'd3;
    localparam logic [31:0] CAUSE_MISALIGNED_LOAD  = 32'd4;
    localparam logic [31:0] CAUSE_MISALIGNED_STORE = 32'd6;
    localparam logic [31:0] CAUSE_ECALL_M          = 32'd11;

endpackage