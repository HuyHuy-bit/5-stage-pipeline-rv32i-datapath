// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vmem_timing.h for the primary calling header

#include "Vmem_timing__pch.h"

VL_ATTR_COLD void Vmem_timing___024root___eval_static(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval_static\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__Vtrigprevexpr___TOP__clk__0 = vlSelfRef.clk;
}

VL_ATTR_COLD void Vmem_timing___024root___eval_initial(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval_initial\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VL_ATTR_COLD void Vmem_timing___024root___eval_final(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval_final\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmem_timing___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG
VL_ATTR_COLD bool Vmem_timing___024root___eval_phase__stl(Vmem_timing___024root* vlSelf);

VL_ATTR_COLD void Vmem_timing___024root___eval_settle(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval_settle\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __VstlIterCount;
    // Body
    __VstlIterCount = 0U;
    vlSelfRef.__VstlFirstIteration = 1U;
    do {
        if (VL_UNLIKELY(((0x00002710U < __VstlIterCount)))) {
#ifdef VL_DEBUG
            Vmem_timing___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
#endif
            VL_FATAL_MT("rtl/mem_timing.sv", 21, "", "DIDNOTCONVERGE: Settle region did not converge after '--converge-limit' of 10000 tries");
        }
        __VstlIterCount = ((IData)(1U) + __VstlIterCount);
        vlSelfRef.__VstlPhaseResult = Vmem_timing___024root___eval_phase__stl(vlSelf);
        vlSelfRef.__VstlFirstIteration = 0U;
    } while (vlSelfRef.__VstlPhaseResult);
}

VL_ATTR_COLD void Vmem_timing___024root___eval_triggers_vec__stl(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval_triggers_vec__stl\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VstlTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VstlTriggered[0U]) 
                                     | (IData)((IData)(vlSelfRef.__VstlFirstIteration)));
}

VL_ATTR_COLD bool Vmem_timing___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmem_timing___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___dump_triggers__stl\n"); );
    // Body
    if ((1U & (~ (IData)(Vmem_timing___024root___trigger_anySet__stl(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'stl' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD bool Vmem_timing___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___trigger_anySet__stl\n"); );
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

VL_ATTR_COLD void Vmem_timing___024root___eval_stl(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval_stl\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VstlTriggered[0U])) {
        vlSelfRef.ready = (1U & ((~ (IData)(vlSelfRef.req)) 
                                 | ((IData)(vlSelfRef.mem_timing__DOT__g_slow__DOT__served) 
                                    & (vlSelfRef.addr 
                                       == vlSelfRef.mem_timing__DOT__g_slow__DOT__served_addr))));
    }
}

VL_ATTR_COLD bool Vmem_timing___024root___eval_phase__stl(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___eval_phase__stl\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VstlExecute;
    // Body
    Vmem_timing___024root___eval_triggers_vec__stl(vlSelf);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vmem_timing___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
    }
#endif
    __VstlExecute = Vmem_timing___024root___trigger_anySet__stl(vlSelfRef.__VstlTriggered);
    if (__VstlExecute) {
        Vmem_timing___024root___eval_stl(vlSelf);
    }
    return (__VstlExecute);
}

bool Vmem_timing___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmem_timing___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___dump_triggers__ico\n"); );
    // Body
    if ((1U & (~ (IData)(Vmem_timing___024root___trigger_anySet__ico(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'ico' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

bool Vmem_timing___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vmem_timing___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___dump_triggers__act\n"); );
    // Body
    if ((1U & (~ (IData)(Vmem_timing___024root___trigger_anySet__act(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: @(posedge clk)\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vmem_timing___024root___ctor_var_reset(Vmem_timing___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmem_timing___024root___ctor_var_reset\n"); );
    Vmem_timing__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    const uint64_t __VscopeHash = VL_MURMUR64_HASH(vlSelf->vlNamep);
    vlSelf->clk = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 16707436170211756652ull);
    vlSelf->rst = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 18209466448985614591ull);
    vlSelf->req = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 13082299938826996746ull);
    vlSelf->burst = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6912805633498636985ull);
    vlSelf->addr = VL_SCOPED_RAND_RESET_I(32, __VscopeHash, 14934084843038794831ull);
    vlSelf->ready = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 898948264233693212ull);
    vlSelf->mem_timing__DOT__g_slow__DOT__cnt = VL_SCOPED_RAND_RESET_I(4, __VscopeHash, 17841174020599757735ull);
    vlSelf->mem_timing__DOT__g_slow__DOT__served_addr = VL_SCOPED_RAND_RESET_I(32, __VscopeHash, 9624694200106852797ull);
    vlSelf->mem_timing__DOT__g_slow__DOT__served = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 13728843176552331158ull);
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VstlTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VicoTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VactTriggered[__Vi0] = 0;
    }
    vlSelf->__Vtrigprevexpr___TOP__clk__0 = 0;
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VnbaTriggered[__Vi0] = 0;
    }
}
