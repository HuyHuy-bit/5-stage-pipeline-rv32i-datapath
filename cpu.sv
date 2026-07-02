// cpu.sv - top-level module: 5-stage pipelined RV32I CPU.

module cpu (
    input  logic clk,
    input  logic rst,
    output logic [31:0] dbg_x1,
    output logic [31:0] dbg_x2,
    output logic [31:0] dbg_x3,
    output logic [31:0] dbg_x4,
    output logic [31:0] dbg_x5
);

    // IF stage
    logic [31:0] pc_out, next_pc, pc_plus4_if, instr_if;

    pc u_pc ( .clk(clk), .rst(rst), .next_pc(next_pc), .pc_out(pc_out) );
    assign pc_plus4_if = pc_out + 32'd4;

    instr_mem u_instr_mem ( .addr(pc_out), .instr(instr_if) );
    // control-flow resolution comes from EX (see below) - drives both the
    // next-fetch PC and the flush signals for IF/ID + ID/EX.
    logic        ex_flush;
    logic [31:0] ex_resolved_target;

    assign next_pc = ex_flush ? ex_resolved_target : pc_plus4_if;

    
    // IF/ID register
    logic [31:0] pc_id, pc_plus4_id, instr_id;
    logic        stall_id; // wired up in Step 3 (hazard unit); tied off for now

    assign stall_id = 1'b0;

    if_id_reg u_if_id (
        .clk(clk), .rst(rst),
        .flush(ex_flush),
        .stall(stall_id),
        .pc_in(pc_out), .pc_plus4_in(pc_plus4_if), .instr_in(instr_if),
        .pc_out(pc_id), .pc_plus4_out(pc_plus4_id), .instr_out(instr_id)
    );

    
    // ID stage
    logic [6:0] opcode_id, funct7_id;
    logic [2:0] funct3_id;
    logic [4:0] rs1_addr_id, rs2_addr_id, rd_addr_id;
    assign opcode_id   = instr_id[6:0];
    assign rd_addr_id  = instr_id[11:7];
    assign funct3_id   = instr_id[14:12];
    assign rs1_addr_id = instr_id[19:15];
    assign rs2_addr_id = instr_id[24:20];
    assign funct7_id   = instr_id[31:25];

    logic        reg_write_en_id, alu_src_id, mem_write_id, mem_read_id, branch_id, alu_a_src_id;
    logic [3:0]  alu_op_id;
    logic [1:0]  pc_src_id, wb_src_id;

    control u_control (
        .opcode(opcode_id), .funct3(funct3_id), .funct7(funct7_id),
        .reg_write_en(reg_write_en_id), .alu_src(alu_src_id),
        .mem_write(mem_write_id), .mem_read(mem_read_id),
        .branch(branch_id), .pc_src(pc_src_id), .wb_src(wb_src_id),
        .alu_a_src(alu_a_src_id), .alu_op(alu_op_id)
    );

    logic [31:0] reg_rs1_data_id, reg_rs2_data_id;
    logic [31:0] write_back_data; // driven by WB stage, below

    reg_file u_reg_file (
        .clk(clk), .rst(rst),
        .rs1_addr(rs1_addr_id), .rs2_addr(rs2_addr_id), .rd_addr(rd_addr_wb),
        .rd_data(write_back_data), .rd_write_en(reg_write_en_wb),
        .rs1_data(reg_rs1_data_id), .rs2_data(reg_rs2_data_id),
        .dbg_x1(dbg_x1), .dbg_x2(dbg_x2), .dbg_x3(dbg_x3),
        .dbg_x4(dbg_x4), .dbg_x5(dbg_x5)
    );

    logic [31:0] imm_id;
    imm_gen u_imm_gen ( .instr(instr_id), .imm(imm_id) );

    
    // ID/EX register
    logic [31:0] pc_ex, pc_plus4_ex, rs1_data_ex, rs2_data_ex, imm_ex;
    logic [4:0]  rs1_addr_ex, rs2_addr_ex, rd_addr_ex;
    logic [2:0]  funct3_ex;
    logic        reg_write_en_ex, alu_src_ex, alu_a_src_ex, mem_write_ex, mem_read_ex, branch_ex;
    logic [3:0]  alu_op_ex;
    logic [1:0]  pc_src_ex, wb_src_ex;

    // A taken branch/jump resolves in EX one cycle before this register would
    // otherwise latch the two wrong-path instructions behind it - flush next cycle.
    id_ex_reg u_id_ex (
        .clk(clk), .rst(rst), .flush(ex_flush),
        .pc_in(pc_id), .pc_plus4_in(pc_plus4_id),
        .rs1_data_in(reg_rs1_data_id), .rs2_data_in(reg_rs2_data_id), .imm_in(imm_id),
        .rs1_addr_in(rs1_addr_id), .rs2_addr_in(rs2_addr_id), .rd_addr_in(rd_addr_id),
        .funct3_in(funct3_id),
        .reg_write_en_in(reg_write_en_id), .alu_src_in(alu_src_id), .alu_a_src_in(alu_a_src_id),
        .alu_op_in(alu_op_id), .mem_write_in(mem_write_id), .mem_read_in(mem_read_id),
        .branch_in(branch_id), .pc_src_in(pc_src_id), .wb_src_in(wb_src_id),

        .pc_out(pc_ex), .pc_plus4_out(pc_plus4_ex),
        .rs1_data_out(rs1_data_ex), .rs2_data_out(rs2_data_ex), .imm_out(imm_ex),
        .rs1_addr_out(rs1_addr_ex), .rs2_addr_out(rs2_addr_ex), .rd_addr_out(rd_addr_ex),
        .funct3_out(funct3_ex),
        .reg_write_en_out(reg_write_en_ex), .alu_src_out(alu_src_ex), .alu_a_src_out(alu_a_src_ex),
        .alu_op_out(alu_op_ex), .mem_write_out(mem_write_ex), .mem_read_out(mem_read_ex),
        .branch_out(branch_ex), .pc_src_out(pc_src_ex), .wb_src_out(wb_src_ex)
    );

    
    // EX stage
    // Forwarding: pick rs1/rs2 from EX/MEM or MEM/WB instead of the raw
    // ID/EX-registered value whenever a not-yet-retired instruction ahead
    // in the pipe is about to write the same register.
    logic [1:0] forward_a, forward_b;
    forwarding_unit u_forwarding_unit (
        .rs1_addr_ex(rs1_addr_ex), .rs2_addr_ex(rs2_addr_ex),
        .rd_addr_mem(rd_addr_mem), .reg_write_en_mem(reg_write_en_mem),
        .rd_addr_wb(rd_addr_wb),   .reg_write_en_wb(reg_write_en_wb),
        .forward_a(forward_a), .forward_b(forward_b)
    );

    logic [31:0] rs1_data_ex_fwd, rs2_data_ex_fwd;
    always_comb begin
        case (forward_a)
            2'b01:   rs1_data_ex_fwd = alu_result_mem;   // from EX/MEM
            2'b10:   rs1_data_ex_fwd = write_back_data;  // from MEM/WB (WB-stage mux output)
            default: rs1_data_ex_fwd = rs1_data_ex;      // no hazard - use registered value
        endcase
        case (forward_b)
            2'b01:   rs2_data_ex_fwd = alu_result_mem;
            2'b10:   rs2_data_ex_fwd = write_back_data;
            default: rs2_data_ex_fwd = rs2_data_ex;
        endcase
    end

    logic [31:0] alu_a_ex, alu_b_ex, alu_result_ex;
    assign alu_a_ex = alu_a_src_ex ? pc_ex : rs1_data_ex_fwd;
    assign alu_b_ex = alu_src_ex   ? imm_ex : rs2_data_ex_fwd;

    alu u_alu (
        .a(alu_a_ex), .b(alu_b_ex), .alu_op(alu_op_ex),
        .result(alu_result_ex), .zero()
    );

    logic branch_taken_ex;
    branch_unit u_branch_unit (
        .rs1(rs1_data_ex_fwd), .rs2(rs2_data_ex_fwd), .funct3(funct3_ex),
        .branch(branch_ex), .pc_sel(branch_taken_ex)
    );

    logic [31:0] branch_target_ex, jalr_target_ex;
    assign branch_target_ex = pc_ex + imm_ex;
    assign jalr_target_ex   = (rs1_data_ex_fwd + imm_ex) & ~32'd1;

    // pc_src_ex: 00=none(sequential), 01=conditional branch, 10=jalr, 11=jal
    always_comb begin
        case (pc_src_ex)
            2'b01:   begin ex_flush = branch_taken_ex; ex_resolved_target = branch_target_ex; end
            2'b10:   begin ex_flush = 1'b1;            ex_resolved_target = jalr_target_ex;   end
            2'b11:   begin ex_flush = 1'b1;            ex_resolved_target = branch_target_ex; end
            default: begin ex_flush = 1'b0;            ex_resolved_target = 32'd0;            end
        endcase
    end

    
    // EX/MEM register
    logic [31:0] alu_result_mem, rs2_data_mem, pc_plus4_mem;
    logic [4:0]  rd_addr_mem;
    logic [2:0]  funct3_mem;
    logic        reg_write_en_mem, mem_write_mem, mem_read_mem;
    logic [1:0]  wb_src_mem;

    ex_mem_reg u_ex_mem (
        .clk(clk), .rst(rst),
        .alu_result_in(alu_result_ex), .rs2_data_in(rs2_data_ex_fwd), .pc_plus4_in(pc_plus4_ex),
        .rd_addr_in(rd_addr_ex), .funct3_in(funct3_ex),
        .reg_write_en_in(reg_write_en_ex), .mem_write_in(mem_write_ex), .mem_read_in(mem_read_ex),
        .wb_src_in(wb_src_ex),

        .alu_result_out(alu_result_mem), .rs2_data_out(rs2_data_mem), .pc_plus4_out(pc_plus4_mem),
        .rd_addr_out(rd_addr_mem), .funct3_out(funct3_mem),
        .reg_write_en_out(reg_write_en_mem), .mem_write_out(mem_write_mem), .mem_read_out(mem_read_mem),
        .wb_src_out(wb_src_mem)
    );

    
    // MEM stage
    logic [31:0] mem_read_data_mem;
    data_mem u_data_mem (
        .clk(clk), .mem_write(mem_write_mem), .mem_read(mem_read_mem),
        .funct3(funct3_mem),
        .addr(alu_result_mem), .write_data(rs2_data_mem),
        .read_data(mem_read_data_mem)
    );

    
    // MEM/WB register
    logic [31:0] mem_read_data_wb, alu_result_wb, pc_plus4_wb;
    logic [4:0]  rd_addr_wb;
    logic        reg_write_en_wb;
    logic [1:0]  wb_src_wb;

    mem_wb_reg u_mem_wb (
        .clk(clk), .rst(rst),
        .mem_read_data_in(mem_read_data_mem), .alu_result_in(alu_result_mem), .pc_plus4_in(pc_plus4_mem),
        .rd_addr_in(rd_addr_mem),
        .reg_write_en_in(reg_write_en_mem), .wb_src_in(wb_src_mem),

        .mem_read_data_out(mem_read_data_wb), .alu_result_out(alu_result_wb), .pc_plus4_out(pc_plus4_wb),
        .rd_addr_out(rd_addr_wb),
        .reg_write_en_out(reg_write_en_wb), .wb_src_out(wb_src_wb)
    );

    
    // WB stage
    always_comb begin
        case (wb_src_wb)
            2'b01:   write_back_data = mem_read_data_wb; // loads
            2'b10:   write_back_data = pc_plus4_wb;      // jal / jalr return address
            default: write_back_data = alu_result_wb;    // r/i/lui/auipc
        endcase
    end

endmodule