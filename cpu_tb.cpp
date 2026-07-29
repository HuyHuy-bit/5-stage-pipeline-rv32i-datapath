// cpu_tb.cpp — multi-test RV32I testbench.
// Loads a hex program at runtime (+MEMFILE=), checks registers against a ref
// file (+REFFILE=), and dumps a VCD (+VCD=).  All 32 registers are read via
// Verilator's flattened root (no extra RTL ports needed).
#include "Vcpu.h"
#include "Vcpu___024root.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "verilated_cov.h"
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <memory>
#include <string>
#include <vector>
#include <array>

// ---- arg helpers -------------------------------------------------------
static std::string strarg(int argc, char** argv, const char* pfx, const char* def) {
    for (int i = 1; i < argc; i++)
        if (strncmp(argv[i], pfx, strlen(pfx)) == 0)
            return argv[i] + strlen(pfx);
    return def;
}
static int intarg(int argc, char** argv, const char* pfx, int def) {
    std::string s = strarg(argc, argv, pfx, "");
    return s.empty() ? def : std::stoi(s);
}

// ---- ref-file loader ---------------------------------------------------
static std::map<int,uint32_t> load_ref(const std::string& path) {
    std::map<int,uint32_t> exp;
    if (path.empty()) return exp;
    std::ifstream f(path);
    if (!f) { std::cerr << "Warning: cannot open ref file: " << path << "\n"; return exp; }
    std::string line;
    while (std::getline(f, line)) {
        if (line.empty() || line[0] == '#') continue;
        if (line.rfind("cycles=", 0) == 0) continue;
        if (line[0] != 'x') continue;
        auto eq = line.find('=');
        if (eq == std::string::npos) continue;
        int reg = std::stoi(line.substr(1, eq - 1));
        std::string v = line.substr(eq + 1);
        uint32_t val = (v.find("0x") == 0 || v.find("0X") == 0)
                       ? (uint32_t)std::stoul(v, nullptr, 16)
                       : (uint32_t)std::stoul(v, nullptr, 10);
        exp[reg] = val;
    }
    return exp;
}

// ---- main --------------------------------------------------------------
int main(int argc, char** argv) {
    const std::unique_ptr<VerilatedContext> ctx{new VerilatedContext};
    ctx->commandArgs(argc, argv);   // makes +MEMFILE visible to $value$plusargs

    int         cycles  = intarg(argc, argv, "+CYCLES=",  20);
    std::string reffile = strarg(argc, argv, "+REFFILE=", "");
    std::string vcdfile = strarg(argc, argv, "+VCD=",     "cpu.vcd");
    // Retirement trace for Spike co-simulation. Off unless a path is given,
    // so every existing invocation is unaffected.
    std::string rvfifile = strarg(argc, argv, "+RVFI_TRACE=", "");
    std::vector<std::array<uint32_t,4>> rvfi_log;   // pc, insn, rd, wdata

    const std::unique_ptr<Vcpu> top{new Vcpu{ctx.get()}};

    // +VCD= (empty) disables tracing entirely. Benchmarks run for millions of
    // cycles; dumping every one of them produces gigabytes nobody opens.
    VerilatedVcdC* tfp = nullptr;
    if (!vcdfile.empty()) {
        ctx->traceEverOn(true);
        tfp = new VerilatedVcdC;
        top->trace(tfp, 99);
        tfp->open(vcdfile.c_str());
    }

    auto tick = [&]() {
        top->clk = 0; top->eval(); ctx->timeInc(1); if (tfp) tfp->dump(ctx->time());
        top->clk = 1; top->eval(); ctx->timeInc(1); if (tfp) tfp->dump(ctx->time());
    };

    top->dbg_flush = 0;
    top->rst = 1; tick(); top->rst = 0;

    const int timeout = (cycles > 0 ? cycles : 20) * 50 + 1000;
    uint32_t prev_pc       = 0xFFFFFFFF;
    uint32_t prev_memstall = 0;
    int      same_pc = 0;
    int      ran     = 0;
    for (int i = 0; i < timeout; i++) {
        tick();
        ran++;

        // Sample after the full tick: the posedge has landed, so valid_wb and
        // the rvfi_* shadow registers describe the instruction that occupies
        // WB this cycle, and pipe_stall says whether it actually retires.
        if (!rvfifile.empty() && top->rootp->cpu__DOT__rvfi_valid) {
            rvfi_log.push_back({(uint32_t)top->rootp->cpu__DOT__rvfi_pc,
                                (uint32_t)top->rootp->cpu__DOT__rvfi_insn,
                                (uint32_t)top->rootp->cpu__DOT__rvfi_rd_addr,
                                (uint32_t)top->rootp->cpu__DOT__rvfi_rd_wdata});
        }

        // A frozen pipeline holds the PC by design, so a memory stall looks
        // exactly like a self-loop. Only judge forward progress on cycles the
        // pipeline actually advanced, or a slow memory ends the run instantly.
        uint32_t cur_memstall = top->perf_mem_stall_count;
        bool     stalled      = (cur_memstall != prev_memstall);
        prev_memstall = cur_memstall;
        if (stalled) continue;

        uint32_t cur_pc = top->rootp->cpu__DOT__pc_out;
        if (cur_pc == prev_pc) {
            if (++same_pc >= 6) break;   // parked in a self-loop
        } else {
            same_pc = 0;
        }
        prev_pc = cur_pc;
    }

    if (!rvfifile.empty()) {
        std::ofstream tf(rvfifile);
        for (auto& r : rvfi_log)
            tf << std::hex << std::setfill('0')
               << std::setw(8) << r[0] << " " << std::setw(8) << r[1] << " "
               << std::dec << r[2] << " "
               << std::hex << std::setw(8) << r[3] << "\n";
        std::cout << "RVFI trace: " << rvfi_log.size() << " retirements -> " << rvfifile << "\n";
    }

    // Snapshot the counters before the flush. The flush is a harness action,
    // not part of the workload, and its cycles would otherwise be billed to the
    // benchmark and inflate CPI.
    struct { uint32_t cyc, instret, stalls, flushes, mispred, branches, memstall,
                      icacc, icmiss, dcacc, dcmiss; } pc_snap = {
        top->perf_cycle_count,   top->perf_instr_retired, top->perf_stall_count,
        top->perf_flush_count,   top->perf_mispredict_count, top->perf_branch_count,
        top->perf_mem_stall_count,
        top->perf_icache_access, top->perf_icache_miss,
        top->perf_dcache_access, top->perf_dcache_miss };

    // Write back every dirty D-cache line before anything reads memory. With a
    // write-back cache the newest copy of a word can still be sitting in the
    // cache, so a signature taken straight from data_mem would be stale.
    top->dbg_flush = 1;
    for (int i = 0; i < 2000000 && !top->dbg_flush_done; i++) tick();
    if (!top->dbg_flush_done) std::cerr << "Warning: D-cache flush did not complete\n";
    top->dbg_flush = 0;

    if (tfp) tfp->close();

    std::string sigfile = strarg(argc, argv, "+SIGFILE=", "");
    if (!sigfile.empty()) {
        int sigstart = intarg(argc, argv, "+SIGSTART=", 0);
        int sigend   = intarg(argc, argv, "+SIGEND=", 0);
        std::ofstream sf(sigfile);
        for (int i = sigstart; i < sigend; i++) {
            uint32_t w = top->rootp->cpu__DOT__u_data_mem__DOT__mem_array[i];
            sf << std::hex << std::setw(8) << std::setfill('0') << w << "\n";
        }
        sf.close();
        std::cout << "Signature dumped: " << (sigend - sigstart) << " words -> " << sigfile << "\n";
    }

    // Read all 32 registers from Verilator's flattened model root.
    uint32_t regs[32] = {};
    for (int i = 1; i < 32; i++)
        regs[i] = top->rootp->cpu__DOT__u_reg_file__DOT__reg_array[i];

    // Print register snapshot (non-zero registers only).
    std::cout << "Registers after " << ran << " cycles (ran until PC parked):\n";
    for (int i = 0; i < 32; i++)
        if (regs[i])
            std::cout << "  x" << i << " = " << regs[i]
                      << "  (0x" << std::hex << regs[i] << std::dec << ")\n";

    // Compare against ref file.
    auto expected = load_ref(reffile);
    if (expected.empty()) {
        std::cout << "(no ref file — snapshot only)\n";
        return 0;
    }

    bool ok = true;
    for (auto& [reg, exp] : expected) {
        bool pass = (regs[reg] == exp);
        ok &= pass;
        std::cout << (pass ? "  PASS" : "  FAIL")
                  << "  x" << reg
                  << "  got=0x" << std::hex << regs[reg]
                  << "  exp=0x" << exp << std::dec << "\n";
    }
    std::cout << (ok ? "PASS\n" : "FAIL\n");

    // Performance summary (cycle-count / instret / stall / flush counters,
    // added in response to project-review feedback).
    uint32_t cyc      = pc_snap.cyc;
    uint32_t instret  = pc_snap.instret;
    uint32_t stalls   = pc_snap.stalls;
    uint32_t flushes  = pc_snap.flushes;
    uint32_t mispred  = pc_snap.mispred;
    uint32_t branches = pc_snap.branches;
    uint32_t memstall = pc_snap.memstall;
    double   cpi      = instret ? (double)cyc / (double)instret : 0.0;
    double   acc      = branches ? 100.0 * (double)(branches - mispred) / (double)branches : 0.0;
    std::cout << "  perf: cycles=" << cyc
              << " instret=" << instret
              << " stalls=" << stalls
              << " flushes=" << flushes
              << " memstall=" << memstall
              << " CPI=" << cpi << "\n";
    std::cout << "  bpred: branches=" << branches
              << " mispredicts=" << mispred
              << " accuracy=" << acc << "%\n";

    // Hit rate is 1 - miss/access: accesses counted on completion, misses at
    // the point the line was found absent.
    uint32_t icacc  = pc_snap.icacc;
    uint32_t icmiss = pc_snap.icmiss;
    double   ichr   = icacc ? 100.0 * (double)(icacc - icmiss) / (double)icacc : 0.0;
    std::cout << "  icache: accesses=" << icacc
              << " misses=" << icmiss
              << " hitrate=" << ichr << "%\n";

    uint32_t dcacc  = pc_snap.dcacc;
    uint32_t dcmiss = pc_snap.dcmiss;
    double   dchr   = dcacc ? 100.0 * (double)(dcacc - dcmiss) / (double)dcacc : 0.0;
    std::cout << "  dcache: accesses=" << dcacc
              << " misses=" << dcmiss
              << " hitrate=" << dchr << "%\n";

#if VM_COVERAGE
    // Each invocation (one per test/kernel) writes its own .dat; a build
    // without --coverage never defines VM_COVERAGE, so this is a no-op there.
    std::string covfile = strarg(argc, argv, "+COVERAGE=", "");
    if (!covfile.empty()) VerilatedCov::write(covfile.c_str());
#endif

    return ok ? 0 : 1;
}