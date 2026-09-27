`timescale 1ns/1ps

`include "axi_if.sv"
`include "axi_pkg.sv"

module tb_top;

  import uvm_pkg::*;
  import axi_pkg::*;

  logic ACLK = 0;
  logic ARESETn = 0;

  // 100 MHz clock
  always #5 ACLK = ~ACLK;

  // Interface uses our default 32-bit configuration
  axi_if intf (
    .ACLK(ACLK),
    .ARESETn(ARESETn)
  );

  // DUT
  axi4_mem_slave #(
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32),
    .ID_WIDTH(4)
  ) dut (
    .ACLK(ACLK),
    .ARESETn(ARESETn),

    // Write address channel
    .AWID(intf.AWID),
    .AWADDR(intf.AWADDR),
    .AWLEN(intf.AWLEN),
    .AWSIZE(intf.AWSIZE),
    .AWBURST(intf.AWBURST),
    .AWVALID(intf.AWVALID),
    .AWREADY(intf.AWREADY),

    // Write data channel
    .WDATA(intf.WDATA),
    .WSTRB(intf.WSTRB),
    .WLAST(intf.WLAST),
    .WVALID(intf.WVALID),
    .WREADY(intf.WREADY),

    // Write response channel
    .BID(intf.BID),
    .BRESP(intf.BRESP),
    .BVALID(intf.BVALID),
    .BREADY(intf.BREADY),

    // Read address channel
    .ARID(intf.ARID),
    .ARADDR(intf.ARADDR),
    .ARLEN(intf.ARLEN),
    .ARSIZE(intf.ARSIZE),
    .ARBURST(intf.ARBURST),
    .ARVALID(intf.ARVALID),
    .ARREADY(intf.ARREADY),

    // Read data channel
    .RID(intf.RID),
    .RDATA(intf.RDATA),
    .RRESP(intf.RRESP),
    .RLAST(intf.RLAST),
    .RVALID(intf.RVALID),
    .RREADY(intf.RREADY)
  );

  // Startup reset
  initial begin
    repeat (3) @(posedge ACLK);
    #1 ARESETn = 1;
  end

  // Share interface references before starting UVM
  initial begin
    uvm_config_db #(virtual axi_if.MP_WDRV)::set(
      null, "uvm_test_top.env.agent.wr_drv", "vif", intf);

    uvm_config_db #(virtual axi_if.MP_RDRV)::set(
      null, "uvm_test_top.env.agent.rd_drv", "vif", intf);

    uvm_config_db #(virtual axi_if.MP_MON)::set(
      null, "uvm_test_top.env.agent.mon", "vif", intf);

    run_test();
  end

  // Waveform recording
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_top);
  end

  // Simulation watchdog
  initial begin
    #1_000_000;
    $fatal(1, "Simulation timed out");
  end

endmodule
