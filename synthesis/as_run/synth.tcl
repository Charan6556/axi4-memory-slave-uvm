# Genus synthesis script for axi4_mem_slave with SKY130 HD
# Uses design_synth.sv (MEM_BYTES reduced to 256 = 64-entry memory)

# library setup
set_db library $env(HOME)/sky130_lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# reading and elaborating the design
read_hdl -sv design_synth.sv
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
file mkdir reports
report_area   > reports/area.rpt
report_timing > reports/timing.rpt
report_gates  > reports/gates.rpt
report_power  > reports/power.rpt
report_qor    > reports/qor.rpt

# netlist output
write_hdl > reports/axi4_mem_slave_netlist.v

exit
