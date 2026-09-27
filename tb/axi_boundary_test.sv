class axi_boundary_test extends axi_base_test;
  `uvm_component_utils(axi_boundary_test)

  //constructor
  function new(string name = "axi_boundary_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //running memory and page boundary scenarios
  virtual task run_scenario();
    boundary_scenario();
  endtask

endclass
