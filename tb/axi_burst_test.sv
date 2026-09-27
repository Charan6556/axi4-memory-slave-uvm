class axi_burst_test extends axi_base_test;
  `uvm_component_utils(axi_burst_test)

  //constructor
  function new(string name = "axi_burst_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //running four beat INCR burst
  virtual task run_scenario();
    burst_scenario();
  endtask

endclass
