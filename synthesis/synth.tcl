# Genus synthesis script for the 256-byte AXI4 slave variant with SKY130 HD.
# Run from the repository root. This writes new reports under synthesis/reports/.

# library setup
set_db library $env(HOME)/sky130_lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# reading and elaborating the design
read_hdl -sv synthesis/design_synth.sv
elaborate axi4_mem_slave
check_design -unresolved

# constraints: 100 MHz clock on ACLK
create_clock -name clk -period 10 [get_ports ACLK]
set_input_delay  2 -clock clk [all_inputs]
set_output_delay 2 -clock clk [all_outputs]

# synthesis steps
syn_generic
syn_map
syn_opt

# reports
file mkdir synthesis/reports
report_area   > synthesis/reports/area.rpt
report_timing > synthesis/reports/timing.rpt
report_gates  > synthesis/reports/gates.rpt
report_power  > synthesis/reports/power.rpt
report_qor    > synthesis/reports/qor.rpt

# netlist output
write_hdl > synthesis/reports/axi4_mem_slave_netlist.v

exit
