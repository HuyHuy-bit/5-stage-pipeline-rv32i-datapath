// cpu_tb.cpp — multi-test RV32I testbench.
// Loads a hex program at runtime (+MEMFILE=), checks registers against a ref
// file (+REFFILE=), and dumps a VCD (+VCD=).  All 32 registers are read via
// Verilator's flattened root (no extra RTL ports needed).
#include "Vcpu.h"
#include "Vcpu___024root.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <memory>
#include <string>

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

    top->rst = 1; tick(); top->rst = 0;

    const int timeout = (cycles > 0 ? cycles : 20) * 50 + 1000;
    uint32_t prev_pc       = 0xFFFFFFFF;
    uint32_t prev_memstall = 0;
    int      same_pc = 0;
    int      ran     = 0;
    for (int i = 0; i < timeout; i++) {
        tick();
        ran++;

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
    uint32_t cyc     = top->perf_cycle_count;
    uint32_t instret = top->perf_instr_retired;
    uint32_t stalls   = top->perf_stall_count;
    uint32_t flushes  = top->perf_flush_count;
    uint32_t mispred  = top->perf_mispredict_count;
    uint32_t branches = top->perf_branch_count;
    uint32_t memstall = top->perf_mem_stall_count;
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

    return ok ? 0 : 1;
}