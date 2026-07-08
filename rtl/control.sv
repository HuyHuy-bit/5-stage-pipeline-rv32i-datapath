// control.sv - decodes opcode/funct3/funct7 into datapath control signals.
`default_nettype none

import rv32i_pkg::*;

module control (
    input  var logic [6:0] opcode,        // 7-bit opcode from instruction
    input  var logic [2:0] funct3,        // 3-bit funct3 from instruction
    input  var logic [6:0] funct7,        // 7-bit funct7 from instruction
    output var logic       reg_write_en,  // 1 when writing to register file
    output var logic       alu_src,       // 1 when ALU operand B is immediate
    output var logic       mem_write,     // 1 when writing to memory
    output var logic       mem_read,      // 1 when reading from memory
    output var logic       branch,        // 1 when instruction is a branch
    output var logic [3:0] alu_op,        // 4-bit ALU operation code
    output var logic [1:0] pc_src,        // program counter source selector
    output var logic [1:0] wb_src,        // write-back source selector
    output var logic       alu_a_src,     // ALU operand A source (0=rs1, 1=pc)
    output var logic       is_csr,        // 1 = CSR read/write instruction
    output var logic       is_system,     // 1 = privileged SYSTEM op (ECALL/EBREAK/MRET)
    output var logic       illegal        // 1 = unrecognized/illegal instruction
);
    // Intermediate ALU decode mode - collapses the opcode-level decision
    // (add / sub / funct-driven / lui) so the funct3/funct7 decode below
    // only has to run for the one mode that needs it.
    typedef enum logic [1:0] { ALU_ADD, ALU_SUB, ALU_FUNC, ALU_LUI } alu_mode_e;
    alu_mode_e alu_decode_mode;

    always_comb begin
        reg_write_en    = 1'b0;
        alu_src         = 1'b0;
        mem_write       = 1'b0;
        mem_read        = 1'b0;
        branch          = 1'b0;
        wb_src          = 2'b00;
        pc_src          = 2'b00;
        alu_a_src       = 1'b0;
        is_csr          = 1'b0;
        is_system       = 1'b0;
        illegal         = 1'b0;
        alu_decode_mode = ALU_ADD;

        case (opcode)
            OPCODE_R_TYPE: begin
                reg_write_en    = 1'b1;
                alu_src         = 1'b0;
                alu_decode_mode = ALU_FUNC;
            end
            OPCODE_I_TYPE: begin
                reg_write_en    = 1'b1;
                alu_src         = 1'b1;
                alu_decode_mode = ALU_FUNC;
            end
            OPCODE_LOAD: begin
                reg_write_en    = 1'b1;
                alu_src         = 1'b1;
                mem_read        = 1'b1;
                wb_src          = 2'b01;
                alu_decode_mode = ALU_ADD;
            end
            OPCODE_STORE: begin
                alu_src         = 1'b1;
                mem_write       = 1'b1;
                alu_decode_mode = ALU_ADD;
            end
            OPCODE_BRANCH: begin
                alu_src         = 1'b0;
                branch          = 1'b1;
                pc_src          = 2'b01;
                alu_decode_mode = ALU_SUB;
            end
            OPCODE_JAL: begin
                reg_write_en    = 1'b1;
                wb_src          = 2'b10;
                pc_src          = 2'b11;
                alu_decode_mode = ALU_ADD;
            end
            OPCODE_JALR: begin
                reg_write_en    = 1'b1;
                wb_src          = 2'b10;
                pc_src          = 2'b10;
                alu_src         = 1'b1;
                alu_decode_mode = ALU_ADD;
            end
            OPCODE_LUI: begin
                reg_write_en    = 1'b1;
                alu_src         = 1'b1;
                alu_decode_mode = ALU_LUI;
            end
            OPCODE_AUIPC: begin
                reg_write_en    = 1'b1;
                alu_src         = 1'b1;
                alu_a_src       = 1'b1;
                alu_decode_mode = ALU_ADD;
            end
            OPCODE_FENCE: begin
            end
            OPCODE_SYSTEM: begin
                if (funct3 == F3_PRIV) begin
                    // ECALL / EBREAK / MRET - no register write, no ALU use.
                    is_system = 1'b1;
                end else begin
                    // CSRRW/S/C and immediate forms: read old CSR into rd.
                    is_csr       = 1'b1;
                    reg_write_en = 1'b1;
                    wb_src       = 2'b11;   // new WB source: CSR read data
                end
            end
            default: begin
                // Unrecognized opcode -> illegal-instruction trap. No arch
                // state is written (all control signals stay at their safe
                // defaults); the trap is raised at the commit point.
                illegal = 1'b1;
            end
        endcase
    end

    // ALU operation decode - only the ALU_FUNC mode consults funct3/funct7.
    always_comb begin
        case (alu_decode_mode)
            ALU_ADD: alu_op = ALU_OP_ADD;
            ALU_SUB: alu_op = ALU_OP_SUB;
            ALU_LUI: alu_op = ALU_OP_PASSB;
            ALU_FUNC: begin
                case (funct3)
                    3'b000:  alu_op = (opcode == OPCODE_R_TYPE && funct7[5]) ? ALU_OP_SUB : ALU_OP_ADD;
                    3'b111:  alu_op = ALU_OP_AND;
                    3'b110:  alu_op = ALU_OP_OR;
                    3'b100:  alu_op = ALU_OP_XOR;
                    3'b010:  alu_op = ALU_OP_SLT;
                    3'b011:  alu_op = ALU_OP_SLTU;
                    3'b001:  alu_op = ALU_OP_SLL;
                    3'b101:  alu_op = funct7[5] ? ALU_OP_SRA : ALU_OP_SRL;
                    default: alu_op = ALU_OP_ADD;
                endcase
            end
            default: alu_op = ALU_OP_ADD;
        endcase
    end
endmodule

`default_nettype wire