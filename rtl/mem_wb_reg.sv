`default_nettype none

// mem_wb_reg.sv - latches load data + ALU result + control into the WB stage.
module mem_wb_reg (
    input  var logic        clk,
    input  var logic        rst,
    input  var logic        freeze,  // hold contents (memory stall)

    input  var logic [31:0] mem_read_data_in,
    input  var logic [31:0] alu_result_in,
    input  var logic [31:0] pc_plus4_in,
    input  var logic [4:0]  rd_addr_in,

    input  var logic        reg_write_en_in,
    input  var logic [1:0]  wb_src_in,
    input  var logic        valid_in,

    output var logic [31:0] mem_read_data_out,
    output var logic [31:0] alu_result_out,
    output var logic [31:0] pc_plus4_out,
    output var logic [4:0]  rd_addr_out,

    output var logic        reg_write_en_out,
    output var logic [1:0]  wb_src_out,
    output var logic        valid_out
);
    always_ff @(posedge clk) begin
        if (rst) begin
            mem_read_data_out <= 32'd0;
            alu_result_out    <= 32'd0;
            pc_plus4_out      <= 32'd0;
            rd_addr_out       <= 5'd0;
            reg_write_en_out  <= 1'b0;
            wb_src_out        <= 2'b00;
            valid_out         <= 1'b0;
        end else if (!freeze) begin
            mem_read_data_out <= mem_read_data_in;
            alu_result_out    <= alu_result_in;
            pc_plus4_out      <= pc_plus4_in;
            rd_addr_out       <= rd_addr_in;
            reg_write_en_out  <= reg_write_en_in;
            wb_src_out        <= wb_src_in;
            valid_out         <= valid_in;
        end
    end
endmodule

`default_nettype wire
