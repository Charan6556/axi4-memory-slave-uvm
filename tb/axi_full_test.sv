class axi_full_test extends axi_base_test;
  `uvm_component_utils(axi_full_test)

  //constructor
  function new(string name = "axi_full_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //running all scenarios
  virtual task run_scenario();
    smoke_scenario();
    burst_scenario();
    narrow_scenario();
    boundary_scenario();
    error_scenario();
    random_scenario();
  endtask

endclass
