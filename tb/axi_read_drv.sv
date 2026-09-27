class axi_read_drv extends uvm_driver #(axi_read_item);
  `uvm_component_utils(axi_read_drv)

  virtual axi_if.MP_RDRV vif;

  //constructor
  function new (string name = "axi_read_drv", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 //build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db #(virtual axi_if.MP_RDRV)::get(this, "", "vif", vif)) begin
      `uvm_fatal("READ_DRV", "Unable to get interface")
    end
  endfunction
  // Initialize master read signals
  task init_signals();
    vif.rd_cb.ARID    <= '0;
    vif.rd_cb.ARADDR  <= '0;
    vif.rd_cb.ARLEN   <= '0;
    vif.rd_cb.ARSIZE  <= '0;
    vif.rd_cb.ARBURST <= 2'b01;
    vif.rd_cb.ARVALID <= 1'b0;

    vif.rd_cb.RREADY  <= 1'b0;
  endtask

  // Run phase
  task run_phase(uvm_phase phase);
    @(vif.rd_cb);
    init_signals();

    while (vif.rd_cb.ARESETn !== 1'b1) begin
      @(vif.rd_cb);
    end

    forever begin
      seq_item_port.get_next_item(req);
      drive_read(req);
      seq_item_port.item_done();
    end
  endtask
    task drive_read(axi_read_item req);
    int beats;
    beats = int'(req.ARLEN) + 1;

    req.RID   = new[beats];
    req.RDATA = new[beats];
    req.RRESP = new[beats];
    req.RLAST = new[beats];

    // Send read address
    vif.rd_cb.ARID    <= req.ARID;
    vif.rd_cb.ARADDR  <= req.ARADDR;
    vif.rd_cb.ARLEN   <= req.ARLEN;
    vif.rd_cb.ARSIZE  <= req.ARSIZE;
    vif.rd_cb.ARBURST <= req.ARBURST;
    vif.rd_cb.ARVALID <= 1'b1;

    do begin
      @(vif.rd_cb);
    end while (vif.rd_cb.ARREADY !== 1'b1);

    vif.rd_cb.ARVALID <= 1'b0;

    // Accept read data
    vif.rd_cb.RREADY <= 1'b1;

    for (int i = 0; i < beats; i++) begin
      do begin
        @(vif.rd_cb);
      end while (vif.rd_cb.RVALID !== 1'b1);

      req.RID[i]   = vif.rd_cb.RID;
      req.RDATA[i] = vif.rd_cb.RDATA;
      req.RRESP[i] = vif.rd_cb.RRESP;
      req.RLAST[i] = vif.rd_cb.RLAST;
    end

    vif.rd_cb.RREADY <= 1'b0;
  endtask
    // Monitor observation information
  typedef enum {
    RD_ADDR,
    RD_BEAT
  } rd_event_t;

  rd_event_t event_kind;
  int unsigned beat_index;
  longint unsigned cycle;

endclass
