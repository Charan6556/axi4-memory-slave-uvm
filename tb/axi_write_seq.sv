class axi_write_seq extends uvm_sequence #(axi_write_item);
  `uvm_object_utils(axi_write_seq)

  //write address values configured by test
  bit [3:0]  AWID;
  bit [31:0] AWADDR;
  bit [7:0]  AWLEN;
  bit [2:0]  AWSIZE;
  bit [1:0]  AWBURST;

  //write data values configured by test
  bit [31:0] WDATA[];
  bit [3:0]  WSTRB[];

  //constructor
  function new(string name = "axi_write_seq");
    super.new(name);
  endfunction

  //sequence body
  task body();
    int unsigned beats;

    beats = int'(AWLEN) + 1;

    //checking array sizes before sending transaction
    if (WDATA.size() != beats)
      `uvm_fatal("WRITE_SEQ", "WDATA size must equal AWLEN + 1")

    if (WSTRB.size() != beats)
      `uvm_fatal("WRITE_SEQ", "WSTRB size must equal AWLEN + 1")

    //creating write transaction
    req = axi_write_item::type_id::create("req");

    start_item(req);

    //copying configured values into transaction
    req.AWID    = AWID;
    req.AWADDR  = AWADDR;
    req.AWLEN   = AWLEN;
    req.AWSIZE  = AWSIZE;
    req.AWBURST = AWBURST;

    req.WDATA = WDATA;
    req.WSTRB = WSTRB;

    //sending transaction to driver
    finish_item(req);
  endtask

endclass
