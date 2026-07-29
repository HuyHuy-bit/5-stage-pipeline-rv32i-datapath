/* spike-lockstep.ld — linker script for the Spike co-simulation flow.
 *
 * Identical in structure to rv32i-pipeline.ld, but relocated to 0x80000000.
 * Spike reserves low memory for its debug ROM and HTIF, so a program linked
 * at 0x0 (as the normal flow does) cannot be loaded into it at all.
 *
 * The RTL runs the same binary unmodified: instr_mem/data_mem decode only
 * their low address bits, so 0x80000000 aliases straight back to word 0 of
 * each memory — the same place the normal 0x0-based image lands. The only
 * adjustment the RTL needs is its reset vector, hence cpu.sv's RESET_PC
 * parameter. That equivalence is what makes it the *same* program running on
 * both machines, which is the whole premise of a lockstep comparison.
 */

MEMORY
{
    ROM (rxa) : ORIGIN = 0x80000000, LENGTH = 0x200000  /* 2MB -> instr_mem */
    RAM (wxa) : ORIGIN = 0x80300000, LENGTH = 0x10000   /* 64KB -> data_mem */
}

ENTRY(rvtest_entry_point)

SECTIONS
{
    .text.init : { *(.text.init) } > ROM

    .text : {
        *(.text)
        *(.text.*)
    } > ROM

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > ROM

    .data : {
        _data = .;
        *(.data)
        *(.data.*)
        _edata = .;
    } > RAM

    .bss : {
        _bss = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        _ebss = .;
    } > RAM

    .tohost : { *(.tohost) } > RAM

    _end = .;

    . = ORIGIN(RAM) + LENGTH(RAM) - 4;
    _stack_top = .;
}
