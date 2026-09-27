class axi_write_drv extends uvm_driver #(axi_write_item);
  `uvm_component_utils(axi_write_drv)

  virtual axi_if.MP_WDRV vif;
 // constructor
  function new (string name = "axi_write_drv", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 //build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db #(virtual axi_if.MP_WDRV)::get(this, "", "vif", vif)) begin
      `uvm_fatal("WRITE_DRV", "Unable to get interface")
    end
  endfunction
 //runphase
    // Initialize master write signals
  task init_signals();
    vif.wr_cb.AWID    <= '0;
    vif.wr_cb.AWADDR  <= '0;
    vif.wr_cb.AWLEN   <= '0;
    vif.wr_cb.AWSIZE  <= '0;
    vif.wr_cb.AWBURST <= 2'b01;
    vif.wr_cb.AWVALID <= 1'b0;

    vif.wr_cb.WDATA   <= '0;
    vif.wr_cb.WSTRB   <= '0;
    vif.wr_cb.WLAST   <= 1'b0;
    vif.wr_cb.WVALID  <= 1'b0;

    vif.wr_cb.BREADY  <= 1'b0;
  endtask

  // Run phase
  task run_phase(uvm_phase phase);
    @(vif.wr_cb);
    init_signals();

    while (vif.wr_cb.ARESETn !== 1'b1) begin
      @(vif.wr_cb);
    end
    // transaction processing next
    forever begin
      seq_item_port.get_next_item(req);
      drive_write(req);
      seq_item_port.item_done();
    end
  endtask
   // Execute one write burst
  task drive_write(axi_write_item req);
    int beats;
    beats = int'(req.AWLEN) + 1;

    if (req.WDATA.size() != beats || req.WSTRB.size() != beats) begin
      `uvm_fatal("WRITE_DRV", "WDATA and WSTRB must contain AWLEN + 1 entries")
    end

    // Address and data channels progress independently
    fork
      send_aw(req);
      send_w(req);
    join

    // Accept write response
    vif.wr_cb.BREADY <= 1'b1;

    do begin
      @(vif.wr_cb);
    end while (vif.wr_cb.BVALID !== 1'b1);

    req.BID   = vif.wr_cb.BID;
    req.BRESP = vif.wr_cb.BRESP;

    vif.wr_cb.BREADY <= 1'b0;
  endtask

  // Send write address
  task send_aw(axi_write_item req);
    vif.wr_cb.AWID    <= req.AWID;
    vif.wr_cb.AWADDR  <= req.AWADDR;
    vif.wr_cb.AWLEN   <= req.AWLEN;
    vif.wr_cb.AWSIZE  <= req.AWSIZE;
    vif.wr_cb.AWBURST <= req.AWBURST;
    vif.wr_cb.AWVALID <= 1'b1;

    do begin
      @(vif.wr_cb);
    end while (vif.wr_cb.AWREADY !== 1'b1);

    vif.wr_cb.AWVALID <= 1'b0;
  endtask

  // Send write data beats
  task send_w(axi_write_item req);
    int beats;
    beats = int'(req.AWLEN) + 1;

    for (int i = 0; i < beats; i++) begin
      vif.wr_cb.WDATA  <= req.WDATA[i];
      vif.wr_cb.WSTRB  <= req.WSTRB[i];
      vif.wr_cb.WLAST  <= (i == beats - 1);
      vif.wr_cb.WVALID <= 1'b1;

      do begin
        @(vif.wr_cb);
      end while (vif.wr_cb.WREADY !== 1'b1);
    end

    vif.wr_cb.WVALID <= 1'b0;
    vif.wr_cb.WLAST  <= 1'b0;
  endtask

endclass
