class axi_read_seqr extends uvm_sequencer #(axi_read_item);
  `uvm_component_utils(axi_read_seqr)

  function new (string name = "axi_read_seqr", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass
