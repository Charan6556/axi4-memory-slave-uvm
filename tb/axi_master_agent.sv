class axi_master_agent extends uvm_agent;
  `uvm_component_utils(axi_master_agent)

  // Handles for components in the master agent
  axi_write_seqr wr_seqr;
  axi_write_drv  wr_drv;
  axi_read_seqr  rd_seqr;
  axi_read_drv   rd_drv;
  axi_mon        mon;

  //constructor
  function new (string name = "axi_master_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  //build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Monitor exists in active and passive modes
    mon = axi_mon::type_id::create("mon", this);

    // Only an active agent generates traffic
    if (get_is_active() == UVM_ACTIVE) begin
      wr_seqr = axi_write_seqr::type_id::create("wr_seqr", this);
      rd_seqr = axi_read_seqr::type_id::create("rd_seqr", this);
      wr_drv = axi_write_drv::type_id::create("wr_drv", this);
      rd_drv = axi_read_drv::type_id::create("rd_drv", this);
    end
  endfunction
  //connect phase
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
      wr_drv.seq_item_port.connect(wr_seqr.seq_item_export);
      rd_drv.seq_item_port.connect(rd_seqr.seq_item_export);
    end
  endfunction


endclass
