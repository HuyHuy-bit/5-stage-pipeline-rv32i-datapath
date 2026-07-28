// csr.sv - minimal M-mode control/status registers.
`default_nettype none

import rv32i_pkg::*;

module csr (
    input  var logic        clk,
    input  var logic        rst,

    // ---- CSR-instruction access (resolved at commit point in MEM) ----
    input  var logic        csr_access,   // 1 = a CSR instruction is committing
    input  var logic [11:0] csr_addr,     // which CSR (instr[31:20])
    input  var logic [2:0]  csr_funct3,   // CSRRW/S/C / immediate variant
    input  var logic [31:0] csr_wdata,    // rs1 value or zero-extended uimm
    output var logic [31:0] csr_rdata,    // old value -> written back to rd

    // ---- read-only counters, mirrored into mcycle/minstret ----
    input  var logic [31:0] cycle_count,
    input  var logic [31:0] instret_count,

    // ---- trap entry (asserted for one cycle when a trap commits) ----
    input  var logic        trap_en,
    input  var logic [31:0] trap_pc,      // faulting instruction's PC -> mepc
    input  var logic [31:0] trap_cause,   // -> mcause
    input  var logic [31:0] trap_val,     // -> mtval (faulting addr/instr, if any)
    output var logic [31:0] mtvec_out,    // handler base -> PC redirect target

    // ---- MRET (asserted for one cycle when an MRET commits) ----
    input  var logic        mret_en,
    output var logic [31:0] mepc_out      // return address -> PC redirect target
);
    logic [31:0] mtvec, mepc, mcause, mscratch, mtval;
    // mcycle/minstret are R/W in M-mode (software may reinitialize them); a
    // write here only offsets the live counter, no separate storage needed,
    // which keeps a write-then-read round trip trivial to reason about.
    logic [31:0] mcycle_offset, minstret_offset;
    logic [31:0] mcycle_val, minstret_val;
    assign mcycle_val   = cycle_count   + mcycle_offset;
    assign minstret_val = instret_count + minstret_offset;

    assign mtvec_out = mtvec;
    assign mepc_out  = mepc;

    // ---- CSR read (combinational): old value seen by the CSR instruction ----
    always_comb begin
        case (csr_addr)
            CSR_MTVEC:     csr_rdata = mtvec;
            CSR_MEPC:      csr_rdata = mepc;
            CSR_MCAUSE:    csr_rdata = mcause;
            CSR_MSCRATCH:  csr_rdata = mscratch;
            CSR_MTVAL:     csr_rdata = mtval;
            CSR_MISA:      csr_rdata = MISA_VALUE;
            CSR_MVENDORID: csr_rdata = 32'd0;
            CSR_MARCHID:   csr_rdata = 32'd0;
            CSR_MIMPID:    csr_rdata = 32'd0;
            CSR_MHARTID:   csr_rdata = 32'd0;
            CSR_MCYCLE:    csr_rdata = mcycle_val;
            CSR_MINSTRET:  csr_rdata = minstret_val;
            CSR_MCYCLEH:   csr_rdata = 32'd0; // 32-bit counters: upper half never overflows into
            CSR_MINSTRETH: csr_rdata = 32'd0; // in any run this core will see; kept at 0 rather than modeled
            default:       csr_rdata = 32'd0; // unimplemented reads trap illegal before this matters
        endcase
    end

    // ---- compute the CSR-instruction write value (RW=swap, RS=set, RC=clear) ----
    logic [31:0] csr_new;
    always_comb begin
        unique case (csr_funct3)
            F3_CSRRW, F3_CSRRWI: csr_new = csr_wdata;
            F3_CSRRS, F3_CSRRSI: csr_new = csr_rdata |  csr_wdata;
            F3_CSRRC, F3_CSRRCI: csr_new = csr_rdata & ~csr_wdata;
            default:             csr_new = csr_rdata;
        endcase
    end

    // ---- write path (synchronous) ----
    // Priority: a trap (hardware) takes precedence over a CSR instruction in
    // the same cycle; in practice they never coincide since both resolve at
    // the single commit point one instruction at a time, but the ordering is
    // made explicit for safety.
    always_ff @(posedge clk) begin
        if (rst) begin
            mtvec           <= 32'd0;
            mepc            <= 32'd0;
            mcause          <= 32'd0;
            mscratch        <= 32'd0;
            mtval           <= 32'd0;
            mcycle_offset   <= 32'd0;
            minstret_offset <= 32'd0;
        end else if (trap_en) begin
            mepc   <= trap_pc;
            mcause <= trap_cause;
            mtval  <= trap_val;
        end else if (mret_en) begin
            // MRET itself doesn't modify these regs in this minimal model
            // (no mstatus.MPP/MPIE stack); flow restore is via mepc_out.
        end else if (csr_access) begin
            // misa/mvendorid/marchid/mimpid/mhartid are WARL-zero (writes
            // silently dropped) or hardware read-only (structural
            // csr_read_only(addr) traps illegal before this ever fires for
            // mvendorid/marchid/mimpid/mhartid — misa alone has no illegal
            // trap since [11:10]!=11, so it needs the explicit no-op here).
            case (csr_addr)
                CSR_MTVEC:    mtvec    <= csr_new;
                CSR_MEPC:     mepc     <= csr_new;
                CSR_MCAUSE:   mcause   <= csr_new;
                CSR_MSCRATCH: mscratch <= csr_new;
                CSR_MTVAL:    mtval    <= csr_new;
                CSR_MCYCLE:   mcycle_offset   <= csr_new - cycle_count;
                CSR_MINSTRET: minstret_offset <= csr_new - instret_count;
                default:      ; // misa, mvendorid/marchid/mimpid/mhartid: read-only
            endcase
        end
    end
endmodule

`default_nettype wire
