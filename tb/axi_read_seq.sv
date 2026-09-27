class axi_read_seq extends uvm_sequence #(axi_read_item);
  `uvm_object_utils(axi_read_seq)

  //read address values configured by test
  bit [3:0]  ARID;
  bit [31:0] ARADDR;
  bit [7:0]  ARLEN;
  bit [2:0]  ARSIZE;
  bit [1:0]  ARBURST;

  //constructor
  function new(string name = "axi_read_seq");
    super.new(name);
  endfunction

  //sequence body
  task body();

    //creating read transaction
    req = axi_read_item::type_id::create("req");

    start_item(req);

    //copying configured values into transaction
    req.ARID    = ARID;
    req.ARADDR  = ARADDR;
    req.ARLEN   = ARLEN;
    req.ARSIZE  = ARSIZE;
    req.ARBURST = ARBURST;

    //sending transaction to driver
    finish_item(req);
  endtask

endclass
