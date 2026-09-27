class axi_smoke_test extends axi_base_test;
  `uvm_component_utils(axi_smoke_test)

  //creating sequence handles
  axi_write_seq wr_seq;
  axi_read_seq  rd_seq;

  //constructor
  function new(string name = "axi_smoke_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //run phase
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    //creating write and read sequences
    wr_seq = axi_write_seq::type_id::create("wr_seq");
    rd_seq = axi_read_seq::type_id::create("rd_seq");

    //configuring single beat write transaction
    wr_seq.AWID    = 4'h1;
    wr_seq.AWADDR  = 32'h0000_0100;
    wr_seq.AWLEN   = 8'd0;
    wr_seq.AWSIZE  = 3'd2;
    wr_seq.AWBURST = 2'b01;

    //creating one write data beat
    wr_seq.WDATA = new[1];
    wr_seq.WSTRB = new[1];

    wr_seq.WDATA[0] = 32'h5049_5841;
    wr_seq.WSTRB[0] = 4'b1111;

    //starting write sequence
    wr_seq.start(env.agent.wr_seqr);

    //configuring matching read transaction
    rd_seq.ARID    = 4'h2;
    rd_seq.ARADDR  = 32'h0000_0100;
    rd_seq.ARLEN   = 8'd0;
    rd_seq.ARSIZE  = 3'd2;
    rd_seq.ARBURST = 2'b01;

    //starting read sequence
    rd_seq.start(env.agent.rd_seqr);

    //waiting for monitor to process final transaction
    wait_for_monitor();

    phase.drop_objection(this);
  endtask

endclass
