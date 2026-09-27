class axi_error_test extends axi_base_test;
  `uvm_component_utils(axi_error_test)

  //constructor
  function new(string name = "axi_error_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //running unsupported commands and invalid addresses
  virtual task run_scenario();
    error_scenario();
  endtask

endclass
