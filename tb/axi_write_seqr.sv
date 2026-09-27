class axi_write_seqr extends uvm_sequencer #(axi_write_item);

    `uvm_component_utils(axi_write_seqr)

    function new(string name = "axi_write_seqr",uvm_component parent = null);
        super.new(name, parent);
    endfunction
    // Monitor observation information
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
