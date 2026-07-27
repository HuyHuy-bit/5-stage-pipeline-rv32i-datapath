// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vmem_timing__pch.h"

//============================================================
// Constructors

Vmem_timing::Vmem_timing(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vmem_timing__Syms(contextp(), _vcname__, this)}
    , clk{vlSymsp->TOP.clk}
    , rst{vlSymsp->TOP.rst}
    , req{vlSymsp->TOP.req}
    , burst{vlSymsp->TOP.burst}
    , ready{vlSymsp->TOP.ready}
    , addr{vlSymsp->TOP.addr}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vmem_timing::Vmem_timing(const char* _vcname__)
    : Vmem_timing(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vmem_timing::~Vmem_timing() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vmem_timing___024root___eval_debug_assertions(Vmem_timing___024root* vlSelf);
#endif  // VL_DEBUG
void Vmem_timing___024root___eval_static(Vmem_timing___024root* vlSelf);
void Vmem_timing___024root___eval_initial(Vmem_timing___024root* vlSelf);
void Vmem_timing___024root___eval_settle(Vmem_timing___024root* vlSelf);
void Vmem_timing___024root___eval(Vmem_timing___024root* vlSelf);

void Vmem_timing::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vmem_timing::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vmem_timing___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vmem_timing___024root___eval_static(&(vlSymsp->TOP));
        Vmem_timing___024root___eval_initial(&(vlSymsp->TOP));
        Vmem_timing___024root___eval_settle(&(vlSymsp->TOP));
        vlSymsp->__Vm_didInit = true;
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vmem_timing___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vmem_timing::eventsPending() { return false; }

uint64_t Vmem_timing::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vmem_timing::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vmem_timing___024root___eval_final(Vmem_timing___024root* vlSelf);

VL_ATTR_COLD void Vmem_timing::final() {
    contextp()->executingFinal(true);
    Vmem_timing___024root___eval_final(&(vlSymsp->TOP));
    contextp()->executingFinal(false);
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vmem_timing::hierName() const { return vlSymsp->name(); }
const char* Vmem_timing::modelName() const { return "Vmem_timing"; }
unsigned Vmem_timing::threads() const { return 1; }
void Vmem_timing::prepareClone() const { contextp()->prepareClone(); }
void Vmem_timing::atClone() const {
    contextp()->threadPoolpOnClone();
}
