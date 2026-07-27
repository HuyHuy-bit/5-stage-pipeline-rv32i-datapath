// csr.sv - minimal M-mode control/status registers: mtvec, mepc, mcause.
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

    // ---- trap entry (asserted for one cycle when a trap commits) ----
    input  var logic        trap_en,
    input  var logic [31:0] trap_pc,      // faulting instruction's PC -> mepc
    input  var logic [31:0] trap_cause,   // -> mcause
    output var logic [31:0] mtvec_out,    // handler base -> PC redirect target

    // ---- MRET (asserted for one cycle when an MRET commits) ----
    input  var logic        mret_en,
    output var logic [31:0] mepc_out      // return address -> PC redirect target
);
    logic [31:0] mtvec, mepc, mcause;

    assign mtvec_out = mtvec;
    assign mepc_out  = mepc;

    // ---- CSR read (combinational): old value seen by the CSR instruction ----
    always_comb begin
        case (csr_addr)
            CSR_MTVEC:  csr_rdata = mtvec;
            CSR_MEPC:   csr_rdata = mepc;
            CSR_MCAUSE: csr_rdata = mcause;
            default:    csr_rdata = 32'd0;
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
            mtvec  <= 32'd0;
            mepc   <= 32'd0;
            mcause <= 32'd0;
        end else if (trap_en) begin
            mepc   <= trap_pc;
            mcause <= trap_cause;
        end else if (mret_en) begin
            // MRET itself doesn't modify these regs in this minimal model
            // (no mstatus.MPP/MPIE stack); flow restore is via mepc_out.
        end else if (csr_access) begin
            case (csr_addr)
                CSR_MTVEC:  mtvec  <= csr_new;
                CSR_MEPC:   mepc   <= csr_new;
                CSR_MCAUSE: mcause <= csr_new;
                default:    ; // writes to unimplemented CSRs are dropped
            endcase
        end
    end
endmodule

`default_nettype wire
