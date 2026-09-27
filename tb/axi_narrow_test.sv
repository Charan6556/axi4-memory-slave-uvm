class axi_narrow_test extends axi_base_test;
  `uvm_component_utils(axi_narrow_test)

  //constructor
  function new(string name = "axi_narrow_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //running narrow transfers and partial writes
  virtual task run_scenario();
    narrow_scenario();
  endtask

endclass
