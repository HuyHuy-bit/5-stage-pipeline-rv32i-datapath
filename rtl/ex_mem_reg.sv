`default_nettype none

// ex_mem_reg.sv - latches ALU result + store data + control into the MEM stage.
module ex_mem_reg (
    input  var logic        clk,
    input  var logic        rst,
    input  var logic        flush,   // squash the instruction in EX (e.g. trap in MEM)
    input  var logic        freeze,  // hold contents, outranking flush (memory stall)

    input  var logic [31:0] alu_result_in,
    input  var logic [31:0] rs2_data_in,     // store data (passes through EX unchanged)
    input  var logic [31:0] pc_plus4_in,
    input  var logic [4:0]  rd_addr_in,
    input  var logic [2:0]  funct3_in,

    input  var logic        reg_write_en_in,
    input  var logic        mem_write_in,
    input  var logic        mem_read_in,
    input  var logic [1:0]  wb_src_in,
    input  var logic        valid_in,
    input  var logic [31:0] pc_in,          // this instruction's own PC (-> mepc)
    input  var logic        exc_pending_in, // an exception was detected for it
    input  var logic [31:0] exc_cause_in,
    input  var logic        is_csr_in,
    input  var logic        is_system_in,
    input  var logic [11:0] csr_addr_in,
    input  var logic [2:0]  csr_funct3_in,
    input  var logic [31:0] csr_wdata_in,
    input  var logic [31:0] csr_rdata_in,   // old CSR value (read in EX) -> WB
    input  var logic [31:0] instr_in,       // full instr (to distinguish MRET/ECALL/EBREAK)

    output var logic [31:0] alu_result_out,
    output var logic [31:0] rs2_data_out,
    output var logic [31:0] pc_plus4_out,
    output var logic [4:0]  rd_addr_out,
    output var logic [2:0]  funct3_out,

    output var logic        reg_write_en_out,
    output var logic        mem_write_out,
    output var logic        mem_read_out,
    output var logic [1:0]  wb_src_out,
    output var logic        valid_out,
    output var logic [31:0] pc_out,
    output var logic        exc_pending_out,
    output var logic [31:0] exc_cause_out,
    output var logic        is_csr_out,
    output var logic        is_system_out,
    output var logic [11:0] csr_addr_out,
    output var logic [2:0]  csr_funct3_out,
    output var logic [31:0] csr_wdata_out,
    output var logic [31:0] csr_rdata_out,
    output var logic [31:0] instr_out
);
    always_ff @(posedge clk) begin
        if (freeze && !rst) begin
            // hold - a memory stall freezes the whole pipe
        end else if (rst || flush) begin
            alu_result_out   <= 32'd0;
            rs2_data_out     <= 32'd0;
            pc_plus4_out     <= 32'd0;
            rd_addr_out      <= 5'd0;
            funct3_out       <= 3'd0;
            reg_write_en_out <= 1'b0;
            mem_write_out    <= 1'b0;
            mem_read_out     <= 1'b0;
            wb_src_out       <= 2'b00;
            valid_out        <= 1'b0;
            pc_out           <= 32'd0;
            exc_pending_out  <= 1'b0;
            exc_cause_out    <= 32'd0;
            is_csr_out       <= 1'b0;
            is_system_out    <= 1'b0;
            csr_addr_out     <= 12'd0;
            csr_funct3_out   <= 3'd0;
            csr_wdata_out    <= 32'd0;
            csr_rdata_out    <= 32'd0;
            instr_out        <= 32'd0;
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
            valid_out        <= valid_in;
            pc_out           <= pc_in;
            exc_pending_out  <= exc_pending_in;
            exc_cause_out    <= exc_cause_in;
            is_csr_out       <= is_csr_in;
            is_system_out    <= is_system_in;
            csr_addr_out     <= csr_addr_in;
            csr_funct3_out   <= csr_funct3_in;
            csr_wdata_out    <= csr_wdata_in;
            csr_rdata_out    <= csr_rdata_in;
            instr_out        <= instr_in;
        end
    end
endmodule

`default_nettype wire
