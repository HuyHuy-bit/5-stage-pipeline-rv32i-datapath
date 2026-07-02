// id_ex_reg.sv - latches decoded operands + control signals into the EX stage.
module id_ex_reg (
    input  logic        clk,
    input  logic        rst,
    input  logic         flush,     // bubble insert (control hazard from EX, or Step-3 hazard unit)

    // datapath values coming out of ID
    input  logic [31:0] pc_in,
    input  logic [31:0] pc_plus4_in,
    input  logic [31:0] rs1_data_in,
    input  logic [31:0] rs2_data_in,
    input  logic [31:0] imm_in,
    input  logic [4:0]  rs1_addr_in,
    input  logic [4:0]  rs2_addr_in,
    input  logic [4:0]  rd_addr_in,
    input  logic [2:0]  funct3_in,

    // control signals coming out of ID
    input  logic        reg_write_en_in,
    input  logic        alu_src_in,
    input  logic        alu_a_src_in,
    input  logic [3:0]  alu_op_in,
    input  logic        mem_write_in,
    input  logic        mem_read_in,
    input  logic        branch_in,
    input  logic [1:0]  pc_src_in,
    input  logic [1:0]  wb_src_in,

    // outputs into EX
    output logic [31:0] pc_out,
    output logic [31:0] pc_plus4_out,
    output logic [31:0] rs1_data_out,
    output logic [31:0] rs2_data_out,
    output logic [31:0] imm_out,
    output logic [4:0]  rs1_addr_out,
    output logic [4:0]  rs2_addr_out,
    output logic [4:0]  rd_addr_out,
    output logic [2:0]  funct3_out,

    output logic        reg_write_en_out,
    output logic        alu_src_out,
    output logic        alu_a_src_out,
    output logic [3:0]  alu_op_out,
    output logic        mem_write_out,
    output logic        mem_read_out,
    output logic        branch_out,
    output logic [1:0]  pc_src_out,
    output logic [1:0]  wb_src_out
);
    always_ff @(posedge clk) begin
        if (rst || flush) begin
            pc_out           <= 32'd0;
            pc_plus4_out     <= 32'd0;
            rs1_data_out     <= 32'd0;
            rs2_data_out     <= 32'd0;
            imm_out          <= 32'd0;
            rs1_addr_out     <= 5'd0;
            rs2_addr_out     <= 5'd0;
            rd_addr_out      <= 5'd0;
            funct3_out       <= 3'd0;
            // zero every control signal -> this becomes an architectural NOP
            reg_write_en_out <= 1'b0;
            alu_src_out      <= 1'b0;
            alu_a_src_out    <= 1'b0;
            alu_op_out       <= 4'd0;
            mem_write_out    <= 1'b0;
            mem_read_out     <= 1'b0;
            branch_out       <= 1'b0;
            pc_src_out       <= 2'b00;
            wb_src_out       <= 2'b00;
        end else begin
            pc_out           <= pc_in;
            pc_plus4_out     <= pc_plus4_in;
            rs1_data_out     <= rs1_data_in;
            rs2_data_out     <= rs2_data_in;
            imm_out          <= imm_in;
            rs1_addr_out     <= rs1_addr_in;
            rs2_addr_out     <= rs2_addr_in;
            rd_addr_out      <= rd_addr_in;
            funct3_out       <= funct3_in;
            reg_write_en_out <= reg_write_en_in;
            alu_src_out      <= alu_src_in;
            alu_a_src_out    <= alu_a_src_in;
            alu_op_out       <= alu_op_in;
            mem_write_out    <= mem_write_in;
            mem_read_out     <= mem_read_in;
            branch_out       <= branch_in;
            pc_src_out       <= pc_src_in;
            wb_src_out       <= wb_src_in;
        end
    end
endmodule