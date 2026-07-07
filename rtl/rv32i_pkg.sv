// rv32i_pkg.sv - shared constants for the RV32I core.
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
 
endpackage