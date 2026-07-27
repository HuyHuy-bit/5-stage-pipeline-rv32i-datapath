// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vmem_timing.h for the primary calling header

#ifndef VERILATED_VMEM_TIMING___024ROOT_H_
#define VERILATED_VMEM_TIMING___024ROOT_H_  // guard

#include "verilated.h"


class Vmem_timing__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vmem_timing___024root final {
  public:

    // DESIGN SPECIFIC STATE
    VL_IN8(clk,0,0);
    VL_IN8(rst,0,0);
    VL_IN8(req,0,0);
    VL_IN8(burst,0,0);
    VL_OUT8(ready,0,0);
    CData/*3:0*/ mem_timing__DOT__g_slow__DOT__cnt;
    CData/*0:0*/ mem_timing__DOT__g_slow__DOT__served;
    CData/*0:0*/ __VstlFirstIteration;
    CData/*0:0*/ __VstlPhaseResult;
    CData/*0:0*/ __VicoFirstIteration;
    CData/*0:0*/ __VicoPhaseResult;
    CData/*0:0*/ __Vtrigprevexpr___TOP__clk__0;
    CData/*0:0*/ __VactPhaseResult;
    CData/*0:0*/ __VnbaPhaseResult;
    VL_IN(addr,31,0);
    IData/*31:0*/ mem_timing__DOT__g_slow__DOT__served_addr;
    IData/*31:0*/ __VactIterCount;
    VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VicoTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VactTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VnbaTriggered;

    // INTERNAL VARIABLES
    Vmem_timing__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vmem_timing___024root(Vmem_timing__Syms* symsp, const char* namep);
    ~Vmem_timing___024root();
    VL_UNCOPYABLE(Vmem_timing___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
