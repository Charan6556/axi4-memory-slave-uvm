class axi_env extends uvm_env;
  `uvm_component_utils(axi_env)

  axi_master_agent agent;
  axi_scoreboard   scoreboard;
  axi_coverage     coverage;

  // Constructor
  function new (string name = "axi_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = axi_master_agent::type_id::create("agent", this);
    scoreboard = axi_scoreboard::type_id::create("scoreboard", this);
    coverage = axi_coverage::type_id::create("coverage", this);
  endfunction

  // Connect phase
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Monitor to scoreboard
    agent.mon.wr_ap.connect(scoreboard.wr_imp);
    agent.mon.rd_ap.connect(scoreboard.rd_imp);
    // Monitor to coverage
    agent.mon.wr_ap.connect(coverage.wr_imp);
    agent.mon.rd_ap.connect(coverage.rd_imp);
  endfunction

endclass
