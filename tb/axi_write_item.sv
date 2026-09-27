class axi_write_item extends uvm_sequence_item;
  `uvm_object_utils(axi_write_item)

  // Write address information
  rand bit [3:0]  AWID;
  rand bit [31:0] AWADDR;
  rand bit [7:0]  AWLEN;
  rand bit [2:0]  AWSIZE;
  rand bit [1:0]  AWBURST;

  // One entry per write data beat
  rand bit [31:0] WDATA[];
  rand bit [3:0]  WSTRB[];

  // Response captured from the slave
  logic [3:0] BID;
  logic [1:0] BRESP;

  function new (string name = "axi_write_item");
    super.new(name);
  endfunction
    // Monitor event information
  typedef enum {
    WR_ADDR,
    WR_BEAT,
    WR_RESP
  } wr_event_t;

  wr_event_t event_kind;
  int unsigned beat_index;
  longint unsigned cycle;
  logic WLAST;

endclass
