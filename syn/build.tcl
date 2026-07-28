# build.tcl - out-of-context synth+impl for one cache/latency configuration.
# Usage: vivado -mode batch -source build.tcl -tclargs <name> \
#            <ic_bytes> <ic_block> <ic_ways> <dc_bytes> <dc_block> <dc_ways> <dc_wb> \
#            <imem_depth> <dmem_depth>
#
# Run from a directory containing rtl/*.sv, blank_instr.hex, blank_data.hex,
# and this file's sibling cpu.xdc.
#
# blank_instr.hex/blank_data.hex must be genuinely varied (random.seed(42),
# getrandbits(32) per word) content sized to match <imem_depth>/<dmem_depth) -
# an all-zero or otherwise degenerate memory lets Vivado's synthesis prove
# huge chunks of the datapath are constant and optimize them away, producing
# resource numbers with no relationship to the real design (found the hard
# way: an all-zero placeholder synthesized to 7 LUTs for the whole CPU).
#
# The results this project reports (see docs/MICROARCHITECTURE.md#synthesis)
# used 512 for both <imem_depth> and <dmem_depth>: large enough to exercise
# real address-decode logic, small enough that the core and +1KB-I$ configs
# fit an xc7a35t; the D-cache configs don't fit regardless of this number
# (see the doc - it's the cache array itself, not backing memory size).

set cfg_name    [lindex $argv 0]
set ic_bytes    [lindex $argv 1]
set ic_block    [lindex $argv 2]
set ic_ways     [lindex $argv 3]
set dc_bytes    [lindex $argv 4]
set dc_block    [lindex $argv 5]
set dc_ways     [lindex $argv 6]
set dc_wb       [lindex $argv 7]
set imem_depth  [lindex $argv 8]
set dmem_depth  [lindex $argv 9]

set part xc7a35ticsg324-1L
set outdir "out_$cfg_name"
file mkdir $outdir

create_project -in_memory -part $part

read_verilog -sv [glob rtl/*.sv]
read_xdc cpu.xdc

synth_design -mode out_of_context -top cpu -part $part \
    -verilog_define SYNTHESIS \
    -generic ICACHE_BYTES=$ic_bytes -generic ICACHE_BLOCK_WORDS=$ic_block -generic ICACHE_WAYS=$ic_ways \
    -generic DCACHE_BYTES=$dc_bytes -generic DCACHE_BLOCK_WORDS=$dc_block -generic DCACHE_WAYS=$dc_ways \
    -generic DCACHE_WRITE_BACK=$dc_wb \
    -generic IMEM_DEPTH_WORDS=$imem_depth -generic DMEM_DEPTH_WORDS=$dmem_depth

write_checkpoint -force "$outdir/post_synth.dcp"
report_utilization -file "$outdir/utilization_synth.rpt"

opt_design
place_design
route_design

write_checkpoint -force "$outdir/post_route.dcp"
report_utilization -file "$outdir/utilization.rpt"
report_timing_summary -delay_type min_max -report_unconstrained -file "$outdir/timing_summary.rpt"
report_timing -delay_type max -max_paths 5 -sort_by group -file "$outdir/critical_paths.rpt"

puts "===BUILD_DONE:$cfg_name==="
