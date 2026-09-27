class axi_read_item extends uvm_sequence_item;
  `uvm_object_utils(axi_read_item)

  // Read address information
  rand bit [3:0]  ARID;
  rand bit [31:0] ARADDR;
  rand bit [7:0]  ARLEN;
  rand bit [2:0]  ARSIZE;
  rand bit [1:0]  ARBURST;

  // Response captured for each read beat
  logic [3:0]  RID[];
  logic [31:0] RDATA[];
  logic [1:0]  RRESP[];
  logic       RLAST[];

  function new (string name = "axi_read_item");
    super.new(name);
  endfunction
    // Monitor event information
  typedef enum {
    RD_ADDR,
    RD_BEAT
  } rd_event_t;

  rd_event_t event_kind;
  int unsigned beat_index;
  longint unsigned cycle;

endclass
