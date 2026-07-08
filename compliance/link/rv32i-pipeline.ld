/* rv32i-pipeline.ld — linker script for the Harvard-split CPU.
 *
 * The CPU has two INDEPENDENT physical memories, each 64KB:
 *   - instr_mem, fed by the PC (fetch address)
 *   - data_mem,  fed by the ALU result (load/store address)
 * Each memory's address decode only looks at its low 16 bits
 * (addr[15:2], word-addressed) — bits above that are ignored.
 *
 */

MEMORY
{
    ROM (rxa) : ORIGIN = 0x00000000, LENGTH = 0x10000   /* 64KB -> instr_mem */
    RAM (wxa) : ORIGIN = 0x00010000, LENGTH = 0x10000   /* 64KB -> data_mem  */
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
