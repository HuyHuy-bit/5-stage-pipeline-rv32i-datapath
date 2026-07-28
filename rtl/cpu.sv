`default_nettype none

// cpu.sv - top-level module: 5-stage pipelined RV32I CPU.
module cpu #(
    parameter int IMEM_LATENCY = 1,
    parameter int DMEM_LATENCY = 1,
    // ICACHE_BYTES = 0 bypasses the cache entirely and wires fetch straight to
    // instr_mem, so the no-cache baseline stays bit-for-bit what it was before
    // the cache existed rather than being a degenerate cache configuration.
    parameter int ICACHE_BYTES       = 0,
    parameter int ICACHE_BLOCK_WORDS = 4,
    parameter int ICACHE_WAYS        = 1,
    parameter int DCACHE_BYTES       = 0,
    parameter int DCACHE_BLOCK_WORDS = 4,
    parameter int DCACHE_WAYS        = 1,
    parameter int DCACHE_WRITE_BACK  = 0,
    // Backing-memory depth. Defaults match the pre-parameterization sizes
    // (2MB instruction ROM, 64KB data RAM) so simulation is unaffected;
    // synthesis overrides these to fit a target device's BRAM budget - see
    // syn/build.tcl.
    parameter int IMEM_DEPTH_WORDS   = 524288,
    parameter int DMEM_DEPTH_WORDS   = 16384
) (
    input  var logic clk,
    input  var logic rst,
    output var logic [31:0] perf_cycle_count,
    output var logic [31:0] perf_instr_retired,
    output var logic [31:0] perf_stall_count,
    output var logic [31:0] perf_flush_count,
    output var logic [31:0] perf_mispredict_count,
    output var logic [31:0] perf_branch_count,
    output var logic [31:0] perf_mem_stall_count,
    output var logic [31:0] perf_icache_access,
    output var logic [31:0] perf_icache_miss,
    output var logic [31:0] perf_dcache_access,
    output var logic [31:0] perf_dcache_miss,
    // Debug: drive high to write every dirty D-cache line back to memory, and
    // wait for dbg_flush_done. Only meaningful for a write-back D-cache, where
    // memory on its own no longer holds all of architectural state.
    input  var logic        dbg_flush,
    output var logic        dbg_flush_done
);

    // IF stage
    logic [31:0] pc_out, next_pc, pc_plus4_if, instr_if;

    pc u_pc ( .clk(clk), .rst(rst), .next_pc(next_pc), .pc_out(pc_out) );
    assign pc_plus4_if = pc_out + 32'd4;

    // Memory stall. Either memory being busy freezes the entire pipeline for
    // the cycle - PC, every pipeline register, the predictor, the CSR file and
    // the counters all hold, so the machine resumes exactly where it left off.
    //
    // ponytail: one global freeze, rather than letting the back end drain
    // through an instruction-fetch miss. That costs some overlap the real
    // thing would recover, and it inflates baseline and post-cache numbers
    // alike. Decoupling the front end needs a fetch buffer - worth it only if
    // the I-cache miss rate stays high enough to care.
    logic imem_ready, dmem_ready, pipe_stall;
    assign pipe_stall = !imem_ready || !dmem_ready;

    // Fetch path: optionally through the I-cache, otherwise straight to memory.
    logic [31:0] ic_mem_addr, ic_mem_instr;
    logic        ic_mem_req, ic_mem_burst, ic_mem_ready;
    logic        icache_miss;

    if (ICACHE_BYTES == 0) begin : g_no_icache
        assign ic_mem_addr  = pc_out;
        assign ic_mem_req   = 1'b1;   // bare fetch: every access is independent
        assign ic_mem_burst = 1'b0;
        assign instr_if     = ic_mem_instr;
        assign imem_ready   = ic_mem_ready;
        assign icache_miss  = 1'b0;
    end else begin : g_icache
        icache #(
            .BYTES(ICACHE_BYTES),
            .BLOCK_WORDS(ICACHE_BLOCK_WORDS),
            .WAYS(ICACHE_WAYS)
        ) u_icache (
            .clk(clk), .rst(rst),
            .addr(pc_out), .instr(instr_if), .ready(imem_ready),
            .mem_addr(ic_mem_addr), .mem_req(ic_mem_req), .mem_burst(ic_mem_burst),
            .mem_instr(ic_mem_instr), .mem_ready(ic_mem_ready),
            .miss_pulse(icache_miss)
        );
    end

    instr_mem #(.LATENCY(IMEM_LATENCY), .DEPTH_WORDS(IMEM_DEPTH_WORDS)) u_instr_mem (
        .clk(clk), .rst(rst),
        .req(ic_mem_req), .burst(ic_mem_burst),
        .addr(ic_mem_addr), .instr(ic_mem_instr), .ready(ic_mem_ready)
    );

    // Front-end branch prediction: index BHT+BTB with the fetch PC. On a
    // predicted-taken hit we redirect the very next fetch to the cached
    // target, so a correctly-predicted taken branch costs zero penalty.
    logic        predict_taken_if;
    logic [31:0] predict_target_if;

    // resolution / redirect signals from EX (declared here, driven below)
    logic        ex_flush;             // misprediction recovery this cycle
    logic [31:0] ex_resolved_target;
    logic        load_use_stall;       // driven by hazard_detect, below

    // Predictor update port, driven from EX (declared here for the instance).
    logic        bp_update_en;
    logic [31:0] bp_update_pc;
    logic        bp_update_taken;
    logic [31:0] bp_update_target;

    branch_predictor u_branch_predictor (
        .clk(clk), .rst(rst),
        .pc_predict(pc_out),
        .predict_taken(predict_taken_if),
        .predict_target(predict_target_if),
        .update_en(bp_update_en),
        .update_pc(bp_update_pc),
        .update_taken(bp_update_taken),
        .update_target(bp_update_target)
    );

    // Trap/MRET redirect signals (driven at the commit point in MEM, below).
    logic        trap_redirect;
    logic [31:0] trap_target;

    // Next-PC priority: memory stall (freeze) > trap/MRET (commit point) >
    // EX misprediction recovery > load-use stall (hold) > front-end
    // predicted-taken redirect > sequential.
    assign next_pc = pipe_stall        ? pc_out               // freeze: re-present same fetch
                    : trap_redirect     ? trap_target
                    : ex_flush          ? ex_resolved_target
                    : load_use_stall   ? pc_out               // hold: re-fetch same address
                    : predict_taken_if ? predict_target_if    // speculative taken redirect
                    : pc_plus4_if;

    // IF/ID register
    logic [31:0] pc_id, pc_plus4_id, instr_id;
    logic        valid_id;
    logic        predicted_taken_id;
    logic [31:0] predicted_target_id;

    if_id_reg u_if_id (
        .clk(clk), .rst(rst),
        .flush(ex_flush || trap_redirect),
        .stall(load_use_stall),
        .freeze(pipe_stall),
        .pc_in(pc_out), .pc_plus4_in(pc_plus4_if), .instr_in(instr_if),
        .predicted_taken_in(predict_taken_if), .predicted_target_in(predict_target_if),
        .pc_out(pc_id), .pc_plus4_out(pc_plus4_id), .instr_out(instr_id),
        .valid_out(valid_id),
        .predicted_taken_out(predicted_taken_id), .predicted_target_out(predicted_target_id)
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
    logic        is_csr_id, is_system_id, illegal_id;

    control u_control (
        .opcode(opcode_id), .funct3(funct3_id), .funct7(funct7_id),
        .reg_write_en(reg_write_en_id), .alu_src(alu_src_id),
        .mem_write(mem_write_id), .mem_read(mem_read_id),
        .branch(branch_id), .pc_src(pc_src_id), .wb_src(wb_src_id),
        .alu_a_src(alu_a_src_id), .alu_op(alu_op_id),
        .is_csr(is_csr_id), .is_system(is_system_id), .illegal(illegal_id)
    );

    // CSR instruction operand fields (decoded in ID, used at commit in MEM).
    // CSRRWI/CSRRSI/CSRRCI (funct3[2]==1) use a zero-extended 5-bit uimm from
    // the rs1 field instead of a register value.
    logic [11:0] csr_addr_id;
    logic [31:0] csr_wdata_id;
    assign csr_addr_id  = instr_id[31:20];
    assign csr_wdata_id = funct3_id[2] ? {27'd0, rs1_addr_id} : reg_rs1_data_id;

    logic [31:0] reg_rs1_data_id, reg_rs2_data_id;
    logic [31:0] write_back_data; // driven by WB stage, below

    reg_file u_reg_file (
        .clk(clk), .rst(rst),
        .rs1_addr(rs1_addr_id), .rs2_addr(rs2_addr_id), .rd_addr(rd_addr_wb),
        .rd_data(write_back_data), .rd_write_en(reg_write_en_wb),
        .rs1_data(reg_rs1_data_id), .rs2_data(reg_rs2_data_id)
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
    logic        valid_ex;
    logic        predicted_taken_ex;
    logic [31:0] predicted_target_ex;
    logic        is_csr_ex, is_system_ex, illegal_ex;
    logic [31:0] csr_rdata_ex;   // old CSR value, read combinationally in EX
    logic [11:0] csr_addr_ex;
    logic [31:0] csr_wdata_ex;
    logic [31:0] instr_ex;

    // A taken branch/jump resolves in EX one cycle before this register would
    // otherwise latch the two wrong-path instructions behind it - flush next cycle.
    // A load-use hazard inserts a bubble here too, while IF/ID holds so the
    // stalled instruction re-decodes correctly next cycle.
    logic id_ex_flush;
    assign id_ex_flush = ex_flush || load_use_stall || trap_redirect;

    id_ex_reg u_id_ex (
        .clk(clk), .rst(rst), .flush(id_ex_flush), .freeze(pipe_stall),
        .pc_in(pc_id), .pc_plus4_in(pc_plus4_id),
        .rs1_data_in(reg_rs1_data_id), .rs2_data_in(reg_rs2_data_id), .imm_in(imm_id),
        .rs1_addr_in(rs1_addr_id), .rs2_addr_in(rs2_addr_id), .rd_addr_in(rd_addr_id),
        .funct3_in(funct3_id),
        .reg_write_en_in(reg_write_en_id), .alu_src_in(alu_src_id), .alu_a_src_in(alu_a_src_id),
        .alu_op_in(alu_op_id), .mem_write_in(mem_write_id), .mem_read_in(mem_read_id),
        .branch_in(branch_id), .pc_src_in(pc_src_id), .wb_src_in(wb_src_id),
        .valid_in(valid_id),
        .predicted_taken_in(predicted_taken_id), .predicted_target_in(predicted_target_id),
        .is_csr_in(is_csr_id), .is_system_in(is_system_id), .illegal_in(illegal_id),
        .csr_addr_in(csr_addr_id), .csr_wdata_in(csr_wdata_id), .instr_in(instr_id),

        .pc_out(pc_ex), .pc_plus4_out(pc_plus4_ex),
        .rs1_data_out(rs1_data_ex), .rs2_data_out(rs2_data_ex), .imm_out(imm_ex),
        .rs1_addr_out(rs1_addr_ex), .rs2_addr_out(rs2_addr_ex), .rd_addr_out(rd_addr_ex),
        .funct3_out(funct3_ex),
        .reg_write_en_out(reg_write_en_ex), .alu_src_out(alu_src_ex), .alu_a_src_out(alu_a_src_ex),
        .alu_op_out(alu_op_ex), .mem_write_out(mem_write_ex), .mem_read_out(mem_read_ex),
        .branch_out(branch_ex), .pc_src_out(pc_src_ex), .wb_src_out(wb_src_ex),
        .valid_out(valid_ex),
        .predicted_taken_out(predicted_taken_ex), .predicted_target_out(predicted_target_ex),
        .is_csr_out(is_csr_ex), .is_system_out(is_system_ex), .illegal_out(illegal_ex),
        .csr_addr_out(csr_addr_ex), .csr_wdata_out(csr_wdata_ex), .instr_out(instr_ex)
    );

    // Hazard detection (load-use)
    // Checks the instruction now sitting in EX (via the ID/EX register's
    // own outputs) against the instruction currently being decoded in ID.
    hazard_detect u_hazard_detect (
        .mem_read_ex(mem_read_ex), .rd_addr_ex(rd_addr_ex),
        .rs1_addr_id(rs1_addr_id), .rs2_addr_id(rs2_addr_id),
        .stall(load_use_stall)
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

    // The value the EX/MEM stage will actually write back: for a CSR
    // instruction it's the old CSR value, otherwise the ALU result. Forwarding
    // must use THIS, not raw alu_result_mem, or a CSR read forwarded to the
    // next instruction delivers garbage.
    logic [31:0] mem_fwd_value;
    assign mem_fwd_value = is_csr_mem ? csr_rdata_commit : alu_result_mem;

    logic [31:0] rs1_data_ex_fwd, rs2_data_ex_fwd;
    always_comb begin
        case (forward_a)
            2'b01:   rs1_data_ex_fwd = mem_fwd_value;    // from EX/MEM (CSR-aware)
            2'b10:   rs1_data_ex_fwd = write_back_data;  // from MEM/WB (WB-stage mux output)
            default: rs1_data_ex_fwd = rs1_data_ex;      // no hazard - use registered value
        endcase
        case (forward_b)
            2'b01:   rs2_data_ex_fwd = mem_fwd_value;
            2'b10:   rs2_data_ex_fwd = write_back_data;
            default: rs2_data_ex_fwd = rs2_data_ex;
        endcase
    end

    // CSR write data must use the FORWARDED rs1 (register variants), else a
    // csrrw right after an instruction producing rs1 captures a stale value.
    // Immediate variants (funct3[2]==1) use the uimm carried from ID, hazard-free.
    logic [31:0] csr_wdata_ex_fwd;
    assign csr_wdata_ex_fwd = funct3_ex[2] ? csr_wdata_ex   // uimm (from ID, no hazard)
                                           : rs1_data_ex_fwd; // register variant (forwarded)

    logic [31:0] alu_a_ex, alu_b_ex, alu_result_ex;
    assign alu_a_ex = alu_a_src_ex ? pc_ex : rs1_data_ex_fwd;
    assign alu_b_ex = alu_src_ex   ? imm_ex : rs2_data_ex_fwd;

    alu u_alu (
        .a(alu_a_ex), .b(alu_b_ex), .alu_op(alu_op_ex),
        .result(alu_result_ex)
    );

    logic branch_taken_ex;
    branch_unit u_branch_unit (
        .rs1(rs1_data_ex_fwd), .rs2(rs2_data_ex_fwd), .funct3(funct3_ex),
        .branch(branch_ex), .pc_sel(branch_taken_ex)
    );

    logic [31:0] branch_target_ex, jalr_target_ex;
    assign branch_target_ex = pc_ex + imm_ex;
    assign jalr_target_ex   = (rs1_data_ex_fwd + imm_ex) & ~32'd1;

    // Resolve the actual control-flow outcome in EX.
    logic        actual_taken;      // did this instruction actually redirect?
    logic [31:0] actual_target;     // ...and to where
    logic        is_cf_instr;       // is this a control-flow instruction at all?
    always_comb begin
        case (pc_src_ex)
            PC_SRC_BRANCH: begin actual_taken = branch_taken_ex; actual_target = branch_target_ex; is_cf_instr = 1'b1; end
            PC_SRC_JALR:   begin actual_taken = 1'b1;            actual_target = jalr_target_ex;   is_cf_instr = 1'b1; end
            PC_SRC_JAL:    begin actual_taken = 1'b1;            actual_target = branch_target_ex; is_cf_instr = 1'b1; end
            default:       begin actual_taken = 1'b0;            actual_target = 32'd0;            is_cf_instr = 1'b0; end
        endcase
    end

    // The front end predicted a taken redirect to predicted_target_ex (only
    // meaningful when predicted_taken_ex). We mispredicted if:
    //   - actual outcome differs from predicted direction, OR
    //   - both said taken but the cached target was wrong (stale BTB).
    // On a misprediction we flush and redirect to the correct next PC:
    //   taken   -> actual_target
    //   not-taken (but predicted taken) -> the fall-through pc_ex + 4
    logic        mispredict;
    logic [31:0] correct_next_pc;
    always_comb begin
        if (actual_taken && predicted_taken_ex && (actual_target == predicted_target_ex)) begin
            mispredict      = 1'b0;                 // correctly predicted taken to the right place
            correct_next_pc = actual_target;
        end else if (!actual_taken && !predicted_taken_ex) begin
            mispredict      = 1'b0;                 // correctly predicted not-taken
            correct_next_pc = pc_ex + 32'd4;
        end else if (actual_taken) begin
            mispredict      = 1'b1;                 // should have gone taken (or to a different target)
            correct_next_pc = actual_target;
        end else begin
            mispredict      = 1'b1;                 // predicted taken but actually not-taken
            correct_next_pc = pc_ex + 32'd4;
        end
    end

    // Only valid instructions can mispredict (a bubble in EX must not flush).
    // Special case: a non-control-flow instruction that the front end wrongly
    // predicted taken (stale BTB alias) must also recover, back to pc_ex+4.
    logic false_predict;
    assign false_predict = valid_ex && !is_cf_instr && predicted_taken_ex;

    assign ex_flush           = (valid_ex && is_cf_instr && mispredict) || false_predict;
    assign ex_resolved_target = false_predict ? (pc_ex + 32'd4) : correct_next_pc;

    // Predictor learning: update on every resolved control-flow instruction.
    // Not while frozen - ID/EX holds, so the same branch would be presented
    // for as many cycles as the stall lasts and its saturating counter would
    // be driven to the rail by a single resolution.
    assign bp_update_en     = valid_ex && is_cf_instr && !pipe_stall;
    assign bp_update_pc     = pc_ex;
    assign bp_update_taken  = actual_taken;
    assign bp_update_target = actual_target;

    // CSRRW(I) always writes; CSRRS/CSRRC(I) only when the operand is
    // nonzero (rs1 field doubles as the 5-bit uimm for the *I variants, so
    // rs1_addr_ex works for both forms).
    logic csr_attempts_write, csr_access_illegal;
    assign csr_attempts_write = (funct3_ex == F3_CSRRW) || (funct3_ex == F3_CSRRWI)
                               || (rs1_addr_ex != 5'd0);
    assign csr_access_illegal = !csr_implemented(csr_addr_ex)
                               || (csr_attempts_write && csr_read_only(csr_addr_ex));

    // ---- EX-stage exception detection (Part 1: illegal instruction) ----
    // Detected here, but not acted on until the commit point in MEM, so that
    // exceptions resolve in program order (precise). Part 2 adds misaligned
    // load/store here as well.
    logic        exc_pending_ex;
    logic [31:0] exc_cause_ex;
    always_comb begin
        exc_pending_ex = 1'b0;
        exc_cause_ex   = 32'd0;
        if (valid_ex && illegal_ex) begin
            exc_pending_ex = 1'b1;
            exc_cause_ex   = CAUSE_ILLEGAL_INSTR;
        end else if (valid_ex && is_csr_ex && csr_access_illegal) begin
            // Either the address isn't implemented at all, or it's a
            // structurally read-only CSR ([11:10]==11) and this access
            // actually attempts a write (CSRRW(I) always writes; CSRRS/C(I)
            // only when the rs1/uimm operand is nonzero).
            exc_pending_ex = 1'b1;
            exc_cause_ex   = CAUSE_ILLEGAL_INSTR;
        end else if (valid_ex && is_cf_instr && actual_taken && actual_target[1]
                     && (pc_src_ex == PC_SRC_BRANCH || pc_src_ex == PC_SRC_JAL)) begin
            // Without the C extension, a taken branch or JAL must land on a
            // 4-byte boundary. JALR already masks bit 0 of its target (see
            // its assign above) and is out of scope here, matching the plan.
            exc_pending_ex = 1'b1;
            exc_cause_ex   = CAUSE_MISALIGNED_FETCH;
        end else if (valid_ex && mem_read_ex) begin
            if ((funct3_ex[1:0] == 2'b10 && alu_result_ex[1:0] != 2'b00) ||
                (funct3_ex[1:0] == 2'b01 && alu_result_ex[0]   != 1'b0)) begin
                exc_pending_ex = 1'b1;
                exc_cause_ex   = CAUSE_MISALIGNED_LOAD;
            end
        end else if (valid_ex && mem_write_ex) begin
            if ((funct3_ex[1:0] == 2'b10 && alu_result_ex[1:0] != 2'b00) ||
                (funct3_ex[1:0] == 2'b01 && alu_result_ex[0]   != 1'b0)) begin
                exc_pending_ex = 1'b1;
                exc_cause_ex   = CAUSE_MISALIGNED_STORE;
            end
        end
    end

    // ---- CSR read happens at the commit point (MEM), not here ----
    // For a CSR instruction, the old value read from the CSR is produced by the
    // csr module at commit and routed straight into write-back; nothing to do
    // in EX. csr_rdata_ex is carried as 0 (unused) to keep the pipe regs simple.
    assign csr_rdata_ex = 32'd0;

    // EX/MEM register
    logic [31:0] alu_result_mem, rs2_data_mem, pc_plus4_mem;
    logic [4:0]  rd_addr_mem;
    logic [2:0]  funct3_mem;
    logic        reg_write_en_mem, mem_write_mem, mem_read_mem;
    logic [1:0]  wb_src_mem;
    logic        valid_mem;
    logic [31:0] pc_mem;
    logic        exc_pending_mem;
    logic [31:0] exc_cause_mem;
    logic        is_csr_mem, is_system_mem;
    logic [11:0] csr_addr_mem;
    logic [2:0]  csr_funct3_mem;
    logic [31:0] csr_wdata_mem, csr_rdata_mem;
    logic [31:0] instr_mem_r;

    ex_mem_reg u_ex_mem (
        .clk(clk), .rst(rst),
        .flush(trap_redirect),
        .freeze(pipe_stall),
        .alu_result_in(alu_result_ex), .rs2_data_in(rs2_data_ex_fwd), .pc_plus4_in(pc_plus4_ex),
        .rd_addr_in(rd_addr_ex), .funct3_in(funct3_ex),
        .reg_write_en_in(reg_write_en_ex), .mem_write_in(mem_write_ex), .mem_read_in(mem_read_ex),
        .wb_src_in(wb_src_ex), .valid_in(valid_ex),
        .pc_in(pc_ex), .exc_pending_in(exc_pending_ex), .exc_cause_in(exc_cause_ex),
        .is_csr_in(is_csr_ex), .is_system_in(is_system_ex),
        .csr_addr_in(csr_addr_ex), .csr_funct3_in(funct3_ex),
        .csr_wdata_in(csr_wdata_ex_fwd), .csr_rdata_in(csr_rdata_ex), .instr_in(instr_ex),

        .alu_result_out(alu_result_mem), .rs2_data_out(rs2_data_mem), .pc_plus4_out(pc_plus4_mem),
        .rd_addr_out(rd_addr_mem), .funct3_out(funct3_mem),
        .reg_write_en_out(reg_write_en_mem), .mem_write_out(mem_write_mem), .mem_read_out(mem_read_mem),
        .wb_src_out(wb_src_mem), .valid_out(valid_mem),
        .pc_out(pc_mem), .exc_pending_out(exc_pending_mem), .exc_cause_out(exc_cause_mem),
        .is_csr_out(is_csr_mem), .is_system_out(is_system_mem),
        .csr_addr_out(csr_addr_mem), .csr_funct3_out(csr_funct3_mem),
        .csr_wdata_out(csr_wdata_mem), .csr_rdata_out(csr_rdata_mem), .instr_out(instr_mem_r)
    );

    // MEM stage
    logic mem_write_mem_gated;
    assign mem_write_mem_gated = mem_write_mem && !(valid_mem && exc_pending_mem);

    // A faulting access must NOT be presented to memory. If it were, the pipe
    // would freeze waiting for an access to complete while the trap that would
    // release it can only commit once the pipe is unfrozen - a deadlock.
    logic dmem_req;
    assign dmem_req = valid_mem && (mem_read_mem || mem_write_mem) && !exc_pending_mem;

    logic [31:0] mem_read_data_mem;   // load result, extended, into MEM/WB
    logic [3:0]  dm_byte_en;
    logic [31:0] dm_store_word, dm_read_word;

    lsu u_lsu (
        .funct3(funct3_mem), .byte_off(alu_result_mem[1:0]),
        .mem_write(mem_write_mem_gated), .mem_read(mem_read_mem),
        .store_data(rs2_data_mem), .mem_word(dm_read_word),
        .byte_en(dm_byte_en), .store_word(dm_store_word),
        .load_data(mem_read_data_mem)
    );

    // Data path: optionally through the D-cache, otherwise straight to memory.
    logic [31:0] dc_mem_addr, dc_mem_write_word, dc_mem_read_word;
    logic [3:0]  dc_mem_byte_en;
    logic        dc_mem_req, dc_mem_burst, dc_mem_ready;
    logic        dcache_access, dcache_miss;

    if (DCACHE_BYTES == 0) begin : g_no_dcache
        assign dc_mem_addr       = alu_result_mem;
        assign dc_mem_req        = dmem_req;
        assign dc_mem_burst      = 1'b0;
        assign dc_mem_byte_en    = dm_byte_en;
        assign dc_mem_write_word = dm_store_word;
        assign dm_read_word      = dc_mem_read_word;
        assign dmem_ready        = dc_mem_ready;
        assign dcache_access     = 1'b0;
        assign dcache_miss       = 1'b0;
        assign dbg_flush_done    = dbg_flush;   // nothing cached, nothing to do
    end else begin : g_dcache
        dcache #(
            .BYTES(DCACHE_BYTES),
            .BLOCK_WORDS(DCACHE_BLOCK_WORDS),
            .WAYS(DCACHE_WAYS),
            .WRITE_BACK(DCACHE_WRITE_BACK)
        ) u_dcache (
            .clk(clk), .rst(rst),
            .req(dmem_req), .addr(alu_result_mem),
            .byte_en(dm_byte_en), .write_word(dm_store_word),
            .read_word(dm_read_word), .ready(dmem_ready),
            .mem_addr(dc_mem_addr), .mem_req(dc_mem_req), .mem_burst(dc_mem_burst),
            .mem_byte_en(dc_mem_byte_en), .mem_write_word(dc_mem_write_word),
            .mem_read_word(dc_mem_read_word), .mem_ready(dc_mem_ready),
            .flush_req(dbg_flush), .flush_done(dbg_flush_done),
            .access(dcache_access), .miss_pulse(dcache_miss)
        );
    end

    data_mem #(.LATENCY(DMEM_LATENCY), .DEPTH_WORDS(DMEM_DEPTH_WORDS)) u_data_mem (
        .clk(clk), .rst(rst),
        .req(dc_mem_req), .burst(dc_mem_burst),
        .addr(dc_mem_addr),
        .byte_en(dc_mem_byte_en), .write_word(dc_mem_write_word),
        .read_word(dc_mem_read_word), .ready(dc_mem_ready)
    );

    // ---- Commit point: traps, MRET, and CSR writes all resolve here ----
    // This is the single point where control-flow-changing exceptional events
    // are decided, in program order. An instruction reaching MEM is the oldest
    // in-flight non-retired instruction, so acting here gives precise
    // exceptions for free: everything ahead has committed, everything behind
    // gets flushed.
    logic        trap_take;       // a trap fires this cycle
    logic [31:0] trap_cause_w;
    logic [31:0] trap_val_w;      // -> mtval: faulting address or instruction, if any
    logic        mret_take;       // an MRET commits this cycle
    logic        csr_commit;      // a CSR instruction commits its write this cycle

    logic is_mret_mem, is_ecall_mem, is_ebreak_mem;
    assign is_mret_mem   = is_system_mem && (instr_mem_r == INSTR_MRET);
    assign is_ecall_mem  = is_system_mem && (instr_mem_r == INSTR_ECALL);
    assign is_ebreak_mem = is_system_mem && (instr_mem_r == INSTR_EBREAK);

    always_comb begin
        trap_take    = 1'b0;
        trap_cause_w = 32'd0;
        trap_val_w   = 32'd0;
        mret_take    = 1'b0;
        csr_commit   = 1'b0;

        // !pipe_stall: an instruction sitting in MEM across a memory stall is
        // presented to this block every one of those cycles. Committing only on
        // the cycle the pipeline actually advances keeps trap/MRET/CSR strictly
        // once-per-instruction, and keeps the trap redirect from fighting the
        // frozen PC.
        if (valid_mem && !pipe_stall) begin
            if (exc_pending_mem) begin
                trap_take    = 1'b1;               // illegal instruction (Part 1)
                trap_cause_w = exc_cause_mem;
                // mtval: faulting address for a misaligned access, the
                // offending word for illegal instruction (including an
                // illegal CSR access), 0 for misaligned-fetch (the target
                // isn't carried this far — spec permits mtval reading 0).
                case (exc_cause_mem)
                    CAUSE_ILLEGAL_INSTR:                       trap_val_w = instr_mem_r;
                    CAUSE_MISALIGNED_LOAD, CAUSE_MISALIGNED_STORE: trap_val_w = alu_result_mem;
                    default: trap_val_w = 32'd0;
                endcase
            end else if (is_ecall_mem) begin
                trap_take    = 1'b1;
                trap_cause_w = CAUSE_ECALL_M;
            end else if (is_ebreak_mem) begin
                trap_take    = 1'b1;
                trap_cause_w = CAUSE_BREAKPOINT;
            end else if (is_mret_mem) begin
                mret_take    = 1'b1;
            end else if (is_csr_mem) begin
                csr_commit   = 1'b1;
            end
        end
    end

    logic [31:0] mtvec_val, mepc_val, csr_rdata_commit;
    csr u_csr (
        .clk(clk), .rst(rst),
        .csr_access(csr_commit),
        .csr_addr(csr_addr_mem),
        .csr_funct3(csr_funct3_mem),
        .csr_wdata(csr_wdata_mem),
        .csr_rdata(csr_rdata_commit),   // old CSR value -> write-back to rd
        .cycle_count(perf_cycle_count), .instret_count(perf_instr_retired),
        .trap_en(trap_take),
        .trap_pc(pc_mem),
        .trap_cause(trap_cause_w),
        .trap_val(trap_val_w),
        .mtvec_out(mtvec_val),
        .mret_en(mret_take),
        .mepc_out(mepc_val)
    );

    // Trap/MRET redirect target computed here; signals declared near IF.
    assign trap_redirect = trap_take || mret_take;
    assign trap_target   = trap_take ? mtvec_val : mepc_val;

    // For a committing CSR instruction, the value written back to rd is the
    // OLD csr value. We fold it into the MEM-stage alu_result feeding MEM/WB,
    // since a CSR instruction doesn't use the ALU result for anything else.
    logic [31:0] mem_result_for_wb;
    assign mem_result_for_wb = mem_fwd_value;  // same value used for forwarding

    // MEM/WB register
    logic [31:0] mem_read_data_wb, alu_result_wb, pc_plus4_wb;
    logic [4:0]  rd_addr_wb;
    logic        reg_write_en_wb;
    logic [1:0]  wb_src_wb;
    logic        valid_wb;

    // A trapping instruction must not commit its register write. Gate the
    // reg_write_en flowing into MEM/WB: on a trap, the offending instruction
    // writes no architectural register (only mepc/mcause change).
    logic reg_write_en_mem_gated;
    assign reg_write_en_mem_gated = reg_write_en_mem && !(trap_take);

    mem_wb_reg u_mem_wb (
        .clk(clk), .rst(rst), .freeze(pipe_stall),
        .mem_read_data_in(mem_read_data_mem), .alu_result_in(mem_result_for_wb), .pc_plus4_in(pc_plus4_mem),
        .rd_addr_in(rd_addr_mem),
        .reg_write_en_in(reg_write_en_mem_gated), .wb_src_in(wb_src_mem), .valid_in(valid_mem),

        .mem_read_data_out(mem_read_data_wb), .alu_result_out(alu_result_wb), .pc_plus4_out(pc_plus4_wb),
        .rd_addr_out(rd_addr_wb),
        .reg_write_en_out(reg_write_en_wb), .wb_src_out(wb_src_wb), .valid_out(valid_wb)
    );

    // WB stage
    always_comb begin
        case (wb_src_wb)
            WB_SRC_MEM: write_back_data = mem_read_data_wb; // loads
            WB_SRC_PC4: write_back_data = pc_plus4_wb;      // jal / jalr return address
            default:    write_back_data = alu_result_wb;    // r/i/lui/auipc, and CSR (folded in above)
        endcase
    end

    // Performance counters
    // instret only increments on a genuinely retired instruction (valid_wb),
    // not on bubbles - a flushed/stalled slot reaching WB looks identical to
    // a legitimately non-writing instruction (store, branch) unless the
    // valid bit threaded through every pipeline register distinguishes them.
    //
    // Everything except the cycle count is gated on !pipe_stall. A frozen
    // pipeline re-presents the same instruction to every stage each cycle, so
    // an ungated counter would multiply one event by the length of the stall.
    // Cycles are the exception: those really did elapse, and a stall that
    // didn't show up in the cycle count would defeat the whole point.
    //
    // flush and mispredict are separate events, not the same one counted
    // twice: a flush is any pipeline squash (mispredict OR trap redirect),
    // while a mispredict is specifically a control-flow instruction the
    // predictor got wrong. Predicting a non-branch as taken off a stale BTB
    // alias is a flush but not a branch mispredict, and folding it into the
    // accuracy figure would understate the predictor.
    logic real_mispredict;
    assign real_mispredict = valid_ex && is_cf_instr && mispredict;

    always_ff @(posedge clk) begin
        if (rst) begin
            perf_cycle_count      <= 32'd0;
            perf_instr_retired    <= 32'd0;
            perf_stall_count      <= 32'd0;
            perf_flush_count      <= 32'd0;
            perf_mispredict_count <= 32'd0;
            perf_branch_count     <= 32'd0;
            perf_mem_stall_count  <= 32'd0;
            perf_icache_access    <= 32'd0;
            perf_icache_miss      <= 32'd0;
            perf_dcache_access    <= 32'd0;
            perf_dcache_miss      <= 32'd0;
        end else begin
            perf_cycle_count      <= perf_cycle_count + 32'd1;
            perf_mem_stall_count  <= perf_mem_stall_count + (pipe_stall ? 32'd1 : 32'd0);
            // Accesses are counted where they complete (one per advancing
            // cycle), misses where they are decided (already one pulse each).
            // Hit rate is then 1 - miss/access, which is the only combination
            // that doesn't score a refilled access as a hit as well as a miss.
            perf_icache_access    <= perf_icache_access + (pipe_stall ? 32'd0 : 32'd1);
            perf_icache_miss      <= perf_icache_miss   + (icache_miss ? 32'd1 : 32'd0);
            perf_dcache_access    <= perf_dcache_access
                                     + ((dcache_access && !pipe_stall) ? 32'd1 : 32'd0);
            perf_dcache_miss      <= perf_dcache_miss   + (dcache_miss ? 32'd1 : 32'd0);
            if (!pipe_stall) begin
                perf_instr_retired    <= perf_instr_retired + (valid_wb ? 32'd1 : 32'd0);
                perf_stall_count      <= perf_stall_count   + (load_use_stall ? 32'd1 : 32'd0);
                perf_flush_count      <= perf_flush_count   + ((ex_flush || trap_redirect) ? 32'd1 : 32'd0);
                perf_mispredict_count <= perf_mispredict_count + (real_mispredict ? 32'd1 : 32'd0);
                perf_branch_count     <= perf_branch_count     + (bp_update_en ? 32'd1 : 32'd0);
            end
        end
    end

    // ---- Design invariants, checked every cycle of every test ----
    // Each property below is an invariant already explained in a comment
    // elsewhere in this file; this is that same reasoning made falsifiable.
    // Simulation-only: SVA isn't synthesized, and not every tool ignores it
    // silently the way Verilator's --lint-only does.
`ifndef SYNTHESIS

    // -- control-flow / redirect --
    a_trap_mret_excl: assert property (@(posedge clk) disable iff (rst)
        !(trap_take && mret_take));
    a_freeze_pc_stable: assert property (@(posedge clk) disable iff (rst)
        pipe_stall |=> $stable(pc_out));
    a_redirect_priority_trap: assert property (@(posedge clk) disable iff (rst)
        (trap_redirect && !pipe_stall) |-> (next_pc == trap_target));
    a_redirect_priority_mispredict: assert property (@(posedge clk) disable iff (rst)
        (ex_flush && !pipe_stall && !trap_redirect) |-> (next_pc == ex_resolved_target));

    // -- deadlock / memory --
    a_no_faulting_req: assert property (@(posedge clk) disable iff (rst)
        dmem_req |-> !exc_pending_mem);
    // dbg_flush is a testbench-only cache-drain hook, not a hazard stall — it
    // can legitimately hold pipe_stall for as long as it takes to walk every
    // set/way of the D-cache, which is unbounded by this property's design.
    a_stall_bounded: assert property (@(posedge clk) disable iff (rst || dbg_flush)
        pipe_stall |-> ##[1:256] (pipe_stall == 1'b0));

    // -- register file / writeback --
    // x0-never-written lives in reg_file.sv, next to the array it protects.
    a_bubble_no_retire: assert property (@(posedge clk) disable iff (rst)
        !valid_wb |-> !reg_write_en_wb);
    a_trap_no_retire: assert property (@(posedge clk) disable iff (rst)
        trap_take |-> !reg_write_en_mem_gated);

    // -- forwarding --
    a_fwd_a_priority: assert property (@(posedge clk) disable iff (rst)
        (reg_write_en_mem && rd_addr_mem != 5'd0 && rd_addr_mem == rs1_addr_ex)
        |-> forward_a == 2'b01);
    a_fwd_b_priority: assert property (@(posedge clk) disable iff (rst)
        (reg_write_en_mem && rd_addr_mem != 5'd0 && rd_addr_mem == rs2_addr_ex)
        |-> forward_b == 2'b01);
    a_fwd_a_no_x0: assert property (@(posedge clk) disable iff (rst)
        rs1_addr_ex == 5'd0 |-> forward_a == 2'b00);
    a_fwd_b_no_x0: assert property (@(posedge clk) disable iff (rst)
        rs2_addr_ex == 5'd0 |-> forward_b == 2'b00);
`endif // SYNTHESIS

    // ---- Functional coverage ----
    // SystemVerilog covergroups aren't supported by this toolchain (COVERIGN);
    // cover property is the supported equivalent and feeds the same
    // --coverage database, read back with verilator_coverage. Crosses are
    // written out as explicit conjunctions since there's no native cross.
`ifdef VERILATOR
    logic cov_en; assign cov_en = !rst;

    // forward_a x forward_b (9 crosses)
    genvar gi, gj;
    generate
        for (gi = 0; gi < 3; gi++) begin : g_fwd_a
            for (gj = 0; gj < 3; gj++) begin : g_fwd_b
                cover property (@(posedge clk) disable iff (rst)
                    cov_en && forward_a == gi[1:0] && forward_b == gj[1:0]);
            end
        end
    endgenerate

    // predictor outcome: predicted_taken x actual_taken x target_match, only
    // meaningful for an actual control-flow instruction in EX
    logic cov_target_match;
    assign cov_target_match = (actual_target == predicted_target_ex);
    c_pred_tt_match:   cover property (@(posedge clk) disable iff (rst)
        cov_en && valid_ex && is_cf_instr && predicted_taken_ex && actual_taken && cov_target_match);
    c_pred_tt_mismatch: cover property (@(posedge clk) disable iff (rst)
        cov_en && valid_ex && is_cf_instr && predicted_taken_ex && actual_taken && !cov_target_match);
    c_pred_tn:          cover property (@(posedge clk) disable iff (rst)
        cov_en && valid_ex && is_cf_instr && predicted_taken_ex && !actual_taken);
    c_pred_nt:          cover property (@(posedge clk) disable iff (rst)
        cov_en && valid_ex && is_cf_instr && !predicted_taken_ex && actual_taken);
    c_pred_nn:          cover property (@(posedge clk) disable iff (rst)
        cov_en && valid_ex && is_cf_instr && !predicted_taken_ex && !actual_taken);
    c_false_predict:    cover property (@(posedge clk) disable iff (rst)
        cov_en && false_predict);

    // control-flow type (pc_src_ex) x taken/not-taken
    c_branch_taken:    cover property (@(posedge clk) disable iff (rst)
        cov_en && valid_ex && pc_src_ex == PC_SRC_BRANCH && actual_taken);
    c_branch_nottaken: cover property (@(posedge clk) disable iff (rst)
        cov_en && valid_ex && pc_src_ex == PC_SRC_BRANCH && !actual_taken);
    c_jalr:            cover property (@(posedge clk) disable iff (rst)
        cov_en && valid_ex && pc_src_ex == PC_SRC_JALR);
    c_jal:              cover property (@(posedge clk) disable iff (rst)
        cov_en && valid_ex && pc_src_ex == PC_SRC_JAL);

    // trap cause, each implemented cause hit at least once
    c_cause_illegal:    cover property (@(posedge clk) disable iff (rst)
        cov_en && trap_take && trap_cause_w == CAUSE_ILLEGAL_INSTR);
    c_cause_mis_load:   cover property (@(posedge clk) disable iff (rst)
        cov_en && trap_take && trap_cause_w == CAUSE_MISALIGNED_LOAD);
    c_cause_mis_store:  cover property (@(posedge clk) disable iff (rst)
        cov_en && trap_take && trap_cause_w == CAUSE_MISALIGNED_STORE);
    c_cause_ecall:      cover property (@(posedge clk) disable iff (rst)
        cov_en && trap_take && trap_cause_w == CAUSE_ECALL_M);
    c_cause_ebreak:     cover property (@(posedge clk) disable iff (rst)
        cov_en && trap_take && trap_cause_w == CAUSE_BREAKPOINT);
    c_mret:             cover property (@(posedge clk) disable iff (rst)
        cov_en && mret_take);

    // hazard interactions
    c_load_use_and_mispredict: cover property (@(posedge clk) disable iff (rst)
        cov_en && load_use_stall && ex_flush);
    // trap_redirect only ever fires when !pipe_stall (see the commit-point
    // comment above), so the interesting cross is a trap-eligible instruction
    // parked in MEM *during* a stall, one cycle before it can commit.
    c_trap_pending_and_stall: cover property (@(posedge clk) disable iff (rst)
        cov_en && valid_mem && exc_pending_mem && pipe_stall);
`endif

endmodule

`default_nettype wire
