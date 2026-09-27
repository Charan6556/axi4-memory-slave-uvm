class axi_random_test extends axi_base_test;
  `uvm_component_utils(axi_random_test)

  //constructor
  function new(string name = "axi_random_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //running constrained random transactions
  virtual task run_scenario();
    random_scenario();
  endtask

endclass
