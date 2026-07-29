`default_nettype none

// perf_counters.sv - the core's self-measurement.
//
// Split out of cpu.sv because none of it is datapath: every signal here is an
// observation of the pipeline, not something the pipeline consumes. The
// counting rules below are the whole content of the module, and they are
// easier to check when they aren't interleaved with the logic they observe.
module perf_counters (
    input  var logic clk,
    input  var logic rst,

    // Everything except the cycle count is gated on !pipe_stall. A frozen
    // pipeline re-presents the same instruction to every stage each cycle, so
    // an ungated counter would multiply one event by the length of the stall.
    // Cycles are the exception: those really did elapse, and a stall that
    // didn't show up in the cycle count would defeat the whole point.
    input  var logic pipe_stall,

    // retired: a genuinely retired instruction, not a bubble. A flushed or
    // stalled slot reaching WB looks identical to a legitimately non-writing
    // instruction (store, branch) unless the valid bit threaded through every
    // pipeline register distinguishes them.
    input  var logic retired,
    input  var logic load_use_stall,

    // flush and mispredict are separate events, not the same one counted
    // twice: a flush is any pipeline squash (mispredict OR trap redirect),
    // while a mispredict is specifically a control-flow instruction the
    // predictor got wrong. Predicting a non-branch as taken off a stale BTB
    // alias is a flush but not a branch mispredict, and folding it into the
    // accuracy figure would understate the predictor.
    input  var logic flushed,
    input  var logic mispredicted,
    input  var logic branch_resolved,

    // Accesses are counted where they complete (one per advancing cycle),
    // misses where they are decided (already one pulse each). Hit rate is then
    // 1 - miss/access, the only combination that doesn't score a refilled
    // access as a hit as well as a miss.
    input  var logic icache_miss,
    input  var logic dcache_access,
    input  var logic dcache_miss,

    output var logic [31:0] cycle_count,
    output var logic [31:0] instr_retired,
    output var logic [31:0] stall_count,
    output var logic [31:0] flush_count,
    output var logic [31:0] mispredict_count,
    output var logic [31:0] branch_count,
    output var logic [31:0] mem_stall_count,
    output var logic [31:0] icache_access,
    output var logic [31:0] icache_miss_count,
    output var logic [31:0] dcache_access_count,
    output var logic [31:0] dcache_miss_count
);
    always_ff @(posedge clk) begin
        if (rst) begin
            cycle_count         <= 32'd0;
            instr_retired       <= 32'd0;
            stall_count         <= 32'd0;
            flush_count         <= 32'd0;
            mispredict_count    <= 32'd0;
            branch_count        <= 32'd0;
            mem_stall_count     <= 32'd0;
            icache_access       <= 32'd0;
            icache_miss_count   <= 32'd0;
            dcache_access_count <= 32'd0;
            dcache_miss_count   <= 32'd0;
        end else begin
            cycle_count         <= cycle_count     + 32'd1;
            mem_stall_count     <= mem_stall_count + (pipe_stall ? 32'd1 : 32'd0);
            icache_access       <= icache_access   + (pipe_stall ? 32'd0 : 32'd1);
            icache_miss_count   <= icache_miss_count + (icache_miss ? 32'd1 : 32'd0);
            dcache_access_count <= dcache_access_count
                                   + ((dcache_access && !pipe_stall) ? 32'd1 : 32'd0);
            dcache_miss_count   <= dcache_miss_count + (dcache_miss ? 32'd1 : 32'd0);
            if (!pipe_stall) begin
                instr_retired    <= instr_retired    + (retired         ? 32'd1 : 32'd0);
                stall_count      <= stall_count      + (load_use_stall  ? 32'd1 : 32'd0);
                flush_count      <= flush_count      + (flushed         ? 32'd1 : 32'd0);
                mispredict_count <= mispredict_count + (mispredicted    ? 32'd1 : 32'd0);
                branch_count     <= branch_count     + (branch_resolved ? 32'd1 : 32'd0);
            end
        end
    end
endmodule

`default_nettype wire
