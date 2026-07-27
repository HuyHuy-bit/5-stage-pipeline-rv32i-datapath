// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vmem_timing.h for the primary calling header

#include "Vmem_timing__pch.h"

void Vmem_timing___024root___ctor_var_reset(Vmem_timing___024root* vlSelf);

Vmem_timing___024root::Vmem_timing___024root(Vmem_timing__Syms* symsp, const char* namep)
 {
    vlSymsp = symsp;
    vlNamep = strdup(namep);
    // Reset structure values
    Vmem_timing___024root___ctor_var_reset(this);
}

void Vmem_timing___024root::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

Vmem_timing___024root::~Vmem_timing___024root() {
    VL_DO_DANGLING(std::free(const_cast<char*>(vlNamep)), vlNamep);
}
