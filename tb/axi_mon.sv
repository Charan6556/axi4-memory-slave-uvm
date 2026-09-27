class axi_mon extends uvm_monitor;
  `uvm_component_utils(axi_mon)

  virtual axi_if.MP_MON vif;

  uvm_analysis_port #(axi_write_item) wr_ap;
  uvm_analysis_port #(axi_read_item)  rd_ap;
    // Commands currently being tracked
  axi_write_item wr_cmd;
  axi_read_item rd_cmd;

  // Monitor tracking state
  bit wr_active;
  bit rd_active;

  int unsigned wr_beat;
  int unsigned rd_beat;
  longint unsigned cycle;

  // Constructor
  function new (string name = "axi_mon", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db #(virtual axi_if.MP_MON)::get(this, "", "vif", vif)) begin
      `uvm_fatal("AXI_MON", "Unable to get interface")
    end

    wr_ap = new("wr_ap", this);
    rd_ap = new("rd_ap", this);
  endfunction
  // Sample all channels on the same clock event
  task run_phase(uvm_phase phase);
    wr_active = 0;
    rd_active = 0;
    wr_beat = 0;
    rd_beat = 0;
    cycle = 0;

     forever begin
      @(vif.mon_cb);
      cycle++;

      if (vif.mon_cb.ARESETn !== 1'b1) begin
        wr_active = 0;
        rd_active = 0;
        wr_beat = 0;
        rd_beat = 0;
        wr_cmd = null;
        rd_cmd = null;
     end
      else begin
        sample_write();
        sample_read();
        end
     end
  endtask

  // Creating a fresh write observation
  function axi_write_item make_wr_event();
    axi_write_item item;
    item = axi_write_item::type_id::create("wr_event");

    item.AWID    = wr_cmd.AWID;
    item.AWADDR  = wr_cmd.AWADDR;
    item.AWLEN   = wr_cmd.AWLEN;
    item.AWSIZE  = wr_cmd.AWSIZE;
    item.AWBURST = wr_cmd.AWBURST;
    item.cycle  = cycle;

    return item;
  endfunction

  // Create a fresh read observation
  function axi_read_item make_rd_event();
    axi_read_item item;
    item = axi_read_item::type_id::create("rd_event");

    item.ARID    = rd_cmd.ARID;
    item.ARADDR  = rd_cmd.ARADDR;
    item.ARLEN   = rd_cmd.ARLEN;
    item.ARSIZE  = rd_cmd.ARSIZE;
    item.ARBURST = rd_cmd.ARBURST;
    item.cycle  = cycle;

    return item;
  endfunction

  // Observe write-channel handshakes
  function void sample_write();
    axi_write_item item;

    // Write address
    if (vif.mon_cb.AWVALID === 1'b1 &&
        vif.mon_cb.AWREADY === 1'b1) begin

      if (wr_active) begin
        `uvm_error("AXI_MON", "New AW accepted while a write is outstanding")
      end
      else begin
        wr_cmd = axi_write_item::type_id::create("wr_cmd");

        wr_cmd.AWID    = vif.mon_cb.AWID;
        wr_cmd.AWADDR  = vif.mon_cb.AWADDR;
        wr_cmd.AWLEN   = vif.mon_cb.AWLEN;
        wr_cmd.AWSIZE  = vif.mon_cb.AWSIZE;
        wr_cmd.AWBURST = vif.mon_cb.AWBURST;

        wr_active = 1;
        wr_beat = 0;

        item = make_wr_event();
        item.event_kind = axi_write_item::WR_ADDR;
        wr_ap.write(item);
      end
    end

    // Write data
    if (vif.mon_cb.WVALID === 1'b1 &&
        vif.mon_cb.WREADY === 1'b1) begin

      if (!wr_active) begin
        `uvm_error("AXI_MON", "W beat accepted without a tracked AW command")
      end
      else if (wr_beat >= int'(wr_cmd.AWLEN) + 1) begin
        `uvm_error("AXI_MON", "More W beats accepted than AWLEN specifies")
      end
      else begin
        item = make_wr_event();
        item.event_kind = axi_write_item::WR_BEAT;
        item.beat_index = wr_beat;

        item.WDATA = new[1];
        item.WSTRB = new[1];

        item.WDATA[0] = vif.mon_cb.WDATA;
        item.WSTRB[0] = vif.mon_cb.WSTRB;
        item.WLAST = vif.mon_cb.WLAST;

        wr_ap.write(item);
        wr_beat++;
      end
    end

    // Write response
    if (vif.mon_cb.BVALID === 1'b1 &&
        vif.mon_cb.BREADY === 1'b1) begin

      if (!wr_active) begin
        `uvm_error("AXI_MON", "B response accepted without a tracked write")
      end
      else begin
        if (wr_beat != int'(wr_cmd.AWLEN) + 1) begin
          `uvm_error("AXI_MON", "B response accepted before all expected W beats")
        end

        item = make_wr_event();
        item.event_kind = axi_write_item::WR_RESP;
        item.BID = vif.mon_cb.BID;
        item.BRESP = vif.mon_cb.BRESP;

        wr_ap.write(item);
        wr_active = 0;
        wr_cmd = null;
      end
    end
  endfunction

  // Observe read-channel handshakes
  function void sample_read();
    axi_read_item item;

    // Read address
    if (vif.mon_cb.ARVALID === 1'b1 &&
        vif.mon_cb.ARREADY === 1'b1) begin

      if (rd_active) begin
        `uvm_error("AXI_MON", "New AR accepted while a read is outstanding")
      end
      else begin
        rd_cmd = axi_read_item::type_id::create("rd_cmd");

        rd_cmd.ARID    = vif.mon_cb.ARID;
        rd_cmd.ARADDR  = vif.mon_cb.ARADDR;
        rd_cmd.ARLEN   = vif.mon_cb.ARLEN;
        rd_cmd.ARSIZE  = vif.mon_cb.ARSIZE;
        rd_cmd.ARBURST = vif.mon_cb.ARBURST;

        rd_active = 1;
        rd_beat = 0;

        item = make_rd_event();
        item.event_kind = axi_read_item::RD_ADDR;
        rd_ap.write(item);
      end
    end

    // Read data
    if (vif.mon_cb.RVALID === 1'b1 &&
        vif.mon_cb.RREADY === 1'b1) begin

      if (!rd_active) begin
        `uvm_error("AXI_MON", "R beat accepted without a tracked AR command")
      end
      else begin
        item = make_rd_event();
        item.event_kind = axi_read_item::RD_BEAT;
        item.beat_index = rd_beat;

        item.RID   = new[1];
        item.RDATA = new[1];
        item.RRESP = new[1];
        item.RLAST = new[1];

        item.RID[0]   = vif.mon_cb.RID;
        item.RDATA[0] = vif.mon_cb.RDATA;
        item.RRESP[0] = vif.mon_cb.RRESP;
        item.RLAST[0] = vif.mon_cb.RLAST;

        rd_ap.write(item);
        rd_beat++;

        // Track completion using the commanded beat count
        if (rd_beat == int'(rd_cmd.ARLEN) + 1) begin
          rd_active = 0;
          rd_cmd = null;
        end
      end
    end
  endfunction


endclass
