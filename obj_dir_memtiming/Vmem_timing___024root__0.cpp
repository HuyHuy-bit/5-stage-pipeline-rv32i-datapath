// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vmem_timing.h for the primary calling header

#include "Vmem_timing__pch.h"

void Vmem_timing___024root___eval_triggers_vec__ico(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval_triggers_vec__ico\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VicoTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VicoTriggered[0U]) 
                                     | (IData)((IData)(vlSelfRef.__VicoFirstIteration)));
}

bool Vmem_timing___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___trigger_anySet__ico\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

void Vmem_timing___024root___ico_sequent__TOP__0(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___ico_sequent__TOP__0\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.ready = (1U & ((~ (IData)(vlSelfRef.req)) 
                             | ((IData)(vlSelfRef.mem_timing__DOT__g_slow__DOT__served) 
                                & (vlSelfRef.addr == vlSelfRef.mem_timing__DOT__g_slow__DOT__served_addr))));
}

void Vmem_timing___024root___eval_ico(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval_ico\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VicoTriggered[0U])) {
        vlSelfRef.ready = (1U & ((~ (IData)(vlSelfRef.req)) 
                                 | ((IData)(vlSelfRef.mem_timing__DOT__g_slow__DOT__served) 
                                    & (vlSelfRef.addr 
                                       == vlSelfRef.mem_timing__DOT__g_slow__DOT__served_addr))));
    }
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmem_timing___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

bool Vmem_timing___024root___eval_phase__ico(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval_phase__ico\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VicoExecute;
    // Body
    Vmem_timing___024root___eval_triggers_vec__ico(vlSelf);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vmem_timing___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
    }
#endif
    __VicoExecute = Vmem_timing___024root___trigger_anySet__ico(vlSelfRef.__VicoTriggered);
    if (__VicoExecute) {
        Vmem_timing___024root___eval_ico(vlSelf);
    }
    return (__VicoExecute);
}

void Vmem_timing___024root___eval_triggers_vec__act(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval_triggers_vec__act\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VactTriggered[0U] = (QData)((IData)(
                                                    ((IData)(vlSelfRef.clk) 
                                                     & (~ (IData)(vlSelfRef.__Vtrigprevexpr___TOP__clk__0)))));
    vlSelfRef.__Vtrigprevexpr___TOP__clk__0 = vlSelfRef.clk;
}

bool Vmem_timing___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___trigger_anySet__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

void Vmem_timing___024root___nba_sequent__TOP__0(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___nba_sequent__TOP__0\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __Vdly__mem_timing__DOT__g_slow__DOT__served;
    __Vdly__mem_timing__DOT__g_slow__DOT__served = 0;
    IData/*31:0*/ __Vdly__mem_timing__DOT__g_slow__DOT__served_addr;
    __Vdly__mem_timing__DOT__g_slow__DOT__served_addr = 0;
    CData/*3:0*/ __Vdly__mem_timing__DOT__g_slow__DOT__cnt;
    __Vdly__mem_timing__DOT__g_slow__DOT__cnt = 0;
    // Body
    __Vdly__mem_timing__DOT__g_slow__DOT__cnt = vlSelfRef.mem_timing__DOT__g_slow__DOT__cnt;
    __Vdly__mem_timing__DOT__g_slow__DOT__served = vlSelfRef.mem_timing__DOT__g_slow__DOT__served;
    __Vdly__mem_timing__DOT__g_slow__DOT__served_addr 
        = vlSelfRef.mem_timing__DOT__g_slow__DOT__served_addr;
    if (vlSelfRef.rst) {
        __Vdly__mem_timing__DOT__g_slow__DOT__served = 0U;
        __Vdly__mem_timing__DOT__g_slow__DOT__served_addr = 0U;
        __Vdly__mem_timing__DOT__g_slow__DOT__cnt = 0U;
    } else if ((1U & (~ (IData)(vlSelfRef.ready)))) {
        if (((IData)(vlSelfRef.mem_timing__DOT__g_slow__DOT__cnt) 
             >= (8U & (- (IData)((1U & (~ ((IData)(vlSelfRef.mem_timing__DOT__g_slow__DOT__served) 
                                           & ((IData)(vlSelfRef.burst) 
                                              & (vlSelfRef.addr 
                                                 == 
                                                 ((IData)(4U) 
                                                  + vlSelfRef.mem_timing__DOT__g_slow__DOT__served_addr))))))))))) {
            __Vdly__mem_timing__DOT__g_slow__DOT__served = 1U;
            __Vdly__mem_timing__DOT__g_slow__DOT__served_addr 
                = vlSelfRef.addr;
            __Vdly__mem_timing__DOT__g_slow__DOT__cnt = 0U;
        } else {
            __Vdly__mem_timing__DOT__g_slow__DOT__cnt 
                = (0x0000000fU & ((IData)(1U) + (IData)(vlSelfRef.mem_timing__DOT__g_slow__DOT__cnt)));
        }
    }
    vlSelfRef.mem_timing__DOT__g_slow__DOT__cnt = __Vdly__mem_timing__DOT__g_slow__DOT__cnt;
    vlSelfRef.mem_timing__DOT__g_slow__DOT__served 
        = __Vdly__mem_timing__DOT__g_slow__DOT__served;
    vlSelfRef.mem_timing__DOT__g_slow__DOT__served_addr 
        = __Vdly__mem_timing__DOT__g_slow__DOT__served_addr;
    vlSelfRef.ready = (1U & ((~ (IData)(vlSelfRef.req)) 
                             | ((IData)(vlSelfRef.mem_timing__DOT__g_slow__DOT__served) 
                                & (vlSelfRef.addr == vlSelfRef.mem_timing__DOT__g_slow__DOT__served_addr))));
}

void Vmem_timing___024root___eval_nba(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval_nba\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__served;
    __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__served = 0;
    IData/*31:0*/ __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__served_addr;
    __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__served_addr = 0;
    CData/*3:0*/ __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__cnt;
    __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__cnt = 0;
    // Body
    if ((1ULL & vlSelfRef.__VnbaTriggered[0U])) {
        __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__cnt 
            = vlSelfRef.mem_timing__DOT__g_slow__DOT__cnt;
        __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__served 
            = vlSelfRef.mem_timing__DOT__g_slow__DOT__served;
        __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__served_addr 
            = vlSelfRef.mem_timing__DOT__g_slow__DOT__served_addr;
        if (vlSelfRef.rst) {
            __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__served = 0U;
            __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__served_addr = 0U;
            __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__cnt = 0U;
        } else if ((1U & (~ (IData)(vlSelfRef.ready)))) {
            if (((IData)(vlSelfRef.mem_timing__DOT__g_slow__DOT__cnt) 
                 >= (8U & (- (IData)((1U & (~ ((IData)(vlSelfRef.mem_timing__DOT__g_slow__DOT__served) 
                                               & ((IData)(vlSelfRef.burst) 
                                                  & (vlSelfRef.addr 
                                                     == 
                                                     ((IData)(4U) 
                                                      + vlSelfRef.mem_timing__DOT__g_slow__DOT__served_addr))))))))))) {
                __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__served = 1U;
                __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__served_addr 
                    = vlSelfRef.addr;
                __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__cnt = 0U;
            } else {
                __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__cnt 
                    = (0x0000000fU & ((IData)(1U) + (IData)(vlSelfRef.mem_timing__DOT__g_slow__DOT__cnt)));
            }
        }
        vlSelfRef.mem_timing__DOT__g_slow__DOT__cnt 
            = __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__cnt;
        vlSelfRef.mem_timing__DOT__g_slow__DOT__served 
            = __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__served;
        vlSelfRef.mem_timing__DOT__g_slow__DOT__served_addr 
            = __Vinline__nba_sequent__TOP__0___Vdly__mem_timing__DOT__g_slow__DOT__served_addr;
        vlSelfRef.ready = (1U & ((~ (IData)(vlSelfRef.req)) 
                                 | ((IData)(vlSelfRef.mem_timing__DOT__g_slow__DOT__served) 
                                    & (vlSelfRef.addr 
                                       == vlSelfRef.mem_timing__DOT__g_slow__DOT__served_addr))));
    }
}

void Vmem_timing___024root___trigger_orInto__act_vec_vec(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___trigger_orInto__act_vec_vec\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = (out[n] | in[n]);
        n = ((IData)(1U) + n);
    } while ((0U >= n));
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmem_timing___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

bool Vmem_timing___024root___eval_phase__act(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval_phase__act\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vmem_timing___024root___eval_triggers_vec__act(vlSelf);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vmem_timing___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
    }
#endif
    Vmem_timing___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VnbaTriggered, vlSelfRef.__VactTriggered);
    return (0U);
}

void Vmem_timing___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___trigger_clear__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = 0ULL;
        n = ((IData)(1U) + n);
    } while ((1U > n));
}

bool Vmem_timing___024root___eval_phase__nba(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval_phase__nba\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = Vmem_timing___024root___trigger_anySet__act(vlSelfRef.__VnbaTriggered);
    if (__VnbaExecute) {
        Vmem_timing___024root___eval_nba(vlSelf);
        Vmem_timing___024root___trigger_clear__act(vlSelfRef.__VnbaTriggered);
    }
    return (__VnbaExecute);
}

void Vmem_timing___024root___eval(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __VicoIterCount;
    IData/*31:0*/ __VnbaIterCount;
    // Body
    __VicoIterCount = 0U;
    vlSelfRef.__VicoFirstIteration = 1U;
    do {
        if (VL_UNLIKELY(((0x00002710U < __VicoIterCount)))) {
#ifdef VL_DEBUG
            Vmem_timing___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
#endif
            VL_FATAL_MT("rtl/mem_timing.sv", 21, "", "DIDNOTCONVERGE: Input combinational region did not converge after '--converge-limit' of 10000 tries");
        }
        __VicoIterCount = ((IData)(1U) + __VicoIterCount);
        vlSelfRef.__VicoPhaseResult = Vmem_timing___024root___eval_phase__ico(vlSelf);
        vlSelfRef.__VicoFirstIteration = 0U;
    } while (vlSelfRef.__VicoPhaseResult);
    __VnbaIterCount = 0U;
    do {
        if (VL_UNLIKELY(((0x00002710U < __VnbaIterCount)))) {
#ifdef VL_DEBUG
            Vmem_timing___024root___dump_triggers__act(vlSelfRef.__VnbaTriggered, "nba"s);
#endif
            VL_FATAL_MT("rtl/mem_timing.sv", 21, "", "DIDNOTCONVERGE: NBA region did not converge after '--converge-limit' of 10000 tries");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        vlSelfRef.__VactIterCount = 0U;
        do {
            if (VL_UNLIKELY(((0x00002710U < vlSelfRef.__VactIterCount)))) {
#ifdef VL_DEBUG
                Vmem_timing___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
#endif
                VL_FATAL_MT("rtl/mem_timing.sv", 21, "", "DIDNOTCONVERGE: Active region did not converge after '--converge-limit' of 10000 tries");
            }
            vlSelfRef.__VactIterCount = ((IData)(1U) 
                                         + vlSelfRef.__VactIterCount);
            vlSelfRef.__VactPhaseResult = Vmem_timing___024root___eval_phase__act(vlSelf);
        } while (vlSelfRef.__VactPhaseResult);
        vlSelfRef.__VnbaPhaseResult = Vmem_timing___024root___eval_phase__nba(vlSelf);
    } while (vlSelfRef.__VnbaPhaseResult);
}

#ifdef VL_DEBUG
void Vmem_timing___024root___eval_debug_assertions(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval_debug_assertions\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if (VL_UNLIKELY(((vlSelfRef.clk & 0xfeU)))) {
        Verilated::overWidthError("clk");
    }
    if (VL_UNLIKELY(((vlSelfRef.rst & 0xfeU)))) {
        Verilated::overWidthError("rst");
    }
    if (VL_UNLIKELY(((vlSelfRef.req & 0xfeU)))) {
        Verilated::overWidthError("req");
    }
    if (VL_UNLIKELY(((vlSelfRef.burst & 0xfeU)))) {
        Verilated::overWidthError("burst");
    }
}
#endif  // VL_DEBUG
