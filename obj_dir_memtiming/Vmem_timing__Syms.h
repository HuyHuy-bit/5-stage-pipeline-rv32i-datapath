// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VMEM_TIMING__SYMS_H_
#define VERILATED_VMEM_TIMING__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vmem_timing.h"

// INCLUDE MODULE CLASSES
#include "Vmem_timing___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES) Vmem_timing__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vmem_timing* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MODULE INSTANCE STATE
    Vmem_timing___024root          TOP;

    // CONSTRUCTORS
    Vmem_timing__Syms(VerilatedContext* contextp, const char* namep, Vmem_timing* modelp);
    ~Vmem_timing__Syms();

    // METHODS
    const char* name() const { return TOP.vlNamep; }
};

#endif  // guard
