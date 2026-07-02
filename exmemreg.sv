// ex_mem_reg.sv - latches ALU result + store data + control into the MEM stage.
module ex_mem_reg (
    input  logic        clk,
    input  logic        rst,

    input  logic [31:0] alu_result_in,
    input  logic [31:0] rs2_data_in,     // store data (passes through EX unchanged)
    input  logic [31:0] pc_plus4_in,
    input  logic [4:0]  rd_addr_in,
    input  logic [2:0]  funct3_in,

    input  logic        reg_write_en_in,
    input  logic        mem_write_in,
    input  logic        mem_read_in,
    input  logic [1:0]  wb_src_in,

    output logic [31:0] alu_result_out,
    output logic [31:0] rs2_data_out,
    output logic [31:0] pc_plus4_out,
    output logic [4:0]  rd_addr_out,
    output logic [2:0]  funct3_out,

    output logic        reg_write_en_out,
    output logic        mem_write_out,
    output logic        mem_read_out,
    output logic [1:0]  wb_src_out
);
    always_ff @(posedge clk) begin
        if (rst) begin
            alu_result_out   <= 32'd0;
            rs2_data_out     <= 32'd0;
            pc_plus4_out     <= 32'd0;
            rd_addr_out      <= 5'd0;
            funct3_out       <= 3'd0;
            reg_write_en_out <= 1'b0;
            mem_write_out    <= 1'b0;
            mem_read_out     <= 1'b0;
            wb_src_out       <= 2'b00;
        end else begin
            alu_result_out   <= alu_result_in;
            rs2_data_out     <= rs2_data_in;
            pc_plus4_out     <= pc_plus4_in;
            rd_addr_out      <= rd_addr_in;
            funct3_out       <= funct3_in;
            reg_write_en_out <= reg_write_en_in;
            mem_write_out    <= mem_write_in;
            mem_read_out     <= mem_read_in;
            wb_src_out       <= wb_src_in;
        end
    end
endmodule