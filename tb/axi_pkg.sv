package axi_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  `uvm_analysis_imp_decl(_wr)
  `uvm_analysis_imp_decl(_rd)

  // Transaction items
  `include "axi_write_item.sv"
  `include "axi_read_item.sv"

  // Sequencers
  `include "axi_write_seqr.sv"
  `include "axi_read_seqr.sv"

  // Drivers and monitor
  `include "axi_write_drv.sv"
  `include "axi_read_drv.sv"
  `include "axi_mon.sv"

  // Agent
  `include "axi_master_agent.sv"

  // Checking and coverage
  `include "axi_scoreboard.sv"
  `include "axi_coverage.sv"

  // Environment
  `include "axi_env.sv"

  // Sequences
  `include "axi_write_seq.sv"
  `include "axi_read_seq.sv"

  //including base test
  `include "axi_test.sv"

   //including derived tests
  `include "axi_smoke_test.sv"
  `include "axi_burst_test.sv"
  `include "axi_narrow_test.sv"
  `include "axi_boundary_test.sv"
  `include "axi_error_test.sv"
  `include "axi_random_test.sv"
  `include "axi_full_test.sv"

endpackage
