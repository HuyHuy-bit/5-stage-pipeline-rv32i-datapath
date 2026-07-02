# ---- RV32I single-cycle CPU: Verilator build + multi-test suite ----
TOP      = cpu
TB       = cpu_tb.cpp

CPU_SRCS = cpu.sv pc.sv instr_mem.sv reg_file.sv imm_gen.sv \
           alu.sv control.sv data_mem.sv branch_unit.sv \
           if_id_reg.sv id_ex_reg.sv ex_mem_reg.sv mem_wb_reg.sv \
           forwarding_unit.sv

VFLAGS   = --cc --exe --build --trace -j 0 -Wno-UNUSEDSIGNAL
OBJDIR   = obj_dir
SIM      = $(OBJDIR)/V$(TOP)
ASM      = python3 tools/asm.py

TESTS    = t01_rtype t02_itype t03_memory t04_branch t05_jump t06_lui_auipc
HEXFILES = $(patsubst %,tests/%.hex,$(TESTS))

.PHONY: all sim assemble test lint wave clean

# Default: build, assemble, run the full suite.
all: sim assemble test

# Build the simulator binary.
sim: $(SIM)
$(SIM): $(CPU_SRCS) $(TB)
	verilator $(VFLAGS) --top-module $(TOP) $(CPU_SRCS) $(TB)

# Assemble every test program that is out of date.
assemble: $(HEXFILES)
tests/%.hex: tests/%.s tools/asm.py
	$(ASM) $< $@

# Run every test and print a summary.
test: sim assemble
	@echo "========== RV32I test suite =========="
	@PASS=0; FAIL=0; \
	for t in $(TESTS); do \
	    printf "\n--- $$t ---\n"; \
	    CYCS=$$(grep '^cycles=' tests/$$t.ref 2>/dev/null | cut -d= -f2); \
	    CYCS=$${CYCS:-25}; \
	    if ./$(SIM) +MEMFILE=tests/$$t.hex +REFFILE=tests/$$t.ref \
	               +CYCLES=$$CYCS +VCD=tests/$$t.vcd; then \
	        PASS=$$((PASS+1)); \
	    else \
	        FAIL=$$((FAIL+1)); \
	    fi; \
	done; \
	echo ""; \
	echo "========== $$PASS/$$((PASS+FAIL)) tests passed =========="; \
	[ $$FAIL -eq 0 ]

# Lint only — quick syntax/structure check.
lint:
	verilator --lint-only -Wno-UNUSEDSIGNAL --top-module $(TOP) $(CPU_SRCS)

# Open a specific test waveform: make wave TEST=t04_branch
TEST ?= t01_rtype
wave: sim assemble
	./$(SIM) +MEMFILE=tests/$(TEST).hex +REFFILE=tests/$(TEST).ref \
	         +CYCLES=$$(grep '^cycles=' tests/$(TEST).ref | cut -d= -f2) \
	         +VCD=tests/$(TEST).vcd
	gtkwave tests/$(TEST).vcd &

clean:
	rm -rf $(OBJDIR) tests/*.hex tests/*.vcd cpu.vcd