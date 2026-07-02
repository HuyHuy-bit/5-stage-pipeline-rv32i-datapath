// mem_wb_reg.sv - latches load data + ALU result + control into the WB stage.
module mem_wb_reg (
    input  logic        clk,
    input  logic        rst,

    input  logic [31:0] mem_read_data_in,
    input  logic [31:0] alu_result_in,
    input  logic [31:0] pc_plus4_in,
    input  logic [4:0]  rd_addr_in,

    input  logic        reg_write_en_in,
    input  logic [1:0]  wb_src_in,

    output logic [31:0] mem_read_data_out,
    output logic [31:0] alu_result_out,
    output logic [31:0] pc_plus4_out,
    output logic [4:0]  rd_addr_out,

    output logic        reg_write_en_out,
    output logic [1:0]  wb_src_out
);
    always_ff @(posedge clk) begin
        if (rst) begin
            mem_read_data_out <= 32'd0;
            alu_result_out    <= 32'd0;
            pc_plus4_out      <= 32'd0;
            rd_addr_out       <= 5'd0;
            reg_write_en_out  <= 1'b0;
            wb_src_out        <= 2'b00;
        end else begin
            mem_read_data_out <= mem_read_data_in;
            alu_result_out    <= alu_result_in;
            pc_plus4_out      <= pc_plus4_in;
            rd_addr_out       <= rd_addr_in;
            reg_write_en_out  <= reg_write_en_in;
            wb_src_out        <= wb_src_in;
        end
    end
endmodule