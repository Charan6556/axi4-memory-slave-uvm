class axi_base_test extends uvm_test;
  `uvm_component_utils(axi_base_test)

  //creating environment handle
  axi_env env;

  //constructor
  function new(string name = "axi_base_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi_env::type_id::create("env", this);
  endfunction

  //printing component hierarchy
  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  //waiting for monitor to process final transaction
  task wait_for_monitor();
    repeat (2)
      @(env.agent.mon.vif.mon_cb);
  endtask

  //run phase used by the remaining six tests
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_scenario();
    wait_for_monitor();
    phase.drop_objection(this);
  endtask

  //each derived test selects its scenario
  virtual task run_scenario();
    `uvm_fatal("BASE_TEST", "Select a derived test")
  endtask

  //sending one write burst
  task send_write(
    input bit [31:0] addr,
    input bit [7:0]  len,
    input bit [2:0]  size,
    input bit [31:0] data,
    input bit [3:0]  strb = 4'hF,
    input bit [1:0]  burst = 2'b01,
    input bit [3:0]  id = 4'h1,
    input bit [31:0] increment = 32'd1,
    input bit        random_payload = 1'b0
  );

    axi_write_seq wr_seq;

    int unsigned beats;
    int unsigned step;
    longint unsigned beat_addr;
    longint unsigned word_base;
    longint unsigned limit;
    bit [3:0] mask;
    bit [3:0] random_strb;

    wr_seq = axi_write_seq::type_id::create("wr_seq");

    //configuring write address information
    wr_seq.AWID    = id;
    wr_seq.AWADDR  = addr;
    wr_seq.AWLEN   = len;
    wr_seq.AWSIZE  = size;
    wr_seq.AWBURST = burst;

    beats = int'(len) + 1;

    //creating data and strobe arrays
    wr_seq.WDATA = new[beats];
    wr_seq.WSTRB = new[beats];

    beat_addr = addr;
    step = 1 << size;

    for (int i = 0; i < beats; i++) begin

      //finding legal byte lanes for this beat
      word_base = (beat_addr / 4) * 4;
      limit = ((beat_addr / step) + 1) * step;
      mask = 4'b0000;

      for (int lane = 0; lane < 4; lane++) begin
        if (((word_base + lane) >= beat_addr) &&
            ((word_base + lane) < limit))
          mask[lane] = 1'b1;
      end

      //generating data and strobes
      if (random_payload) begin
        wr_seq.WDATA[i] = $urandom();
        random_strb = $urandom_range(15, 0);
        wr_seq.WSTRB[i] = mask & random_strb;
      end
      else begin
        wr_seq.WDATA[i] = data + (i * increment);
        wr_seq.WSTRB[i] = mask & strb;
      end

      //moving to next INCR beat
      if (burst == 2'b01)
        beat_addr = limit;
    end

    wr_seq.start(env.agent.wr_seqr);
  endtask

  //sending one read burst
  task send_read(
    input bit [31:0] addr,
    input bit [7:0]  len,
    input bit [2:0]  size,
    input bit [1:0]  burst = 2'b01,
    input bit [3:0]  id = 4'h2);

    axi_read_seq rd_seq;

    rd_seq = axi_read_seq::type_id::create("rd_seq");

    //configuring read address information
    rd_seq.ARID    = id;
    rd_seq.ARADDR  = addr;
    rd_seq.ARLEN   = len;
    rd_seq.ARSIZE  = size;
    rd_seq.ARBURST = burst;

    rd_seq.start(env.agent.rd_seqr);
  endtask

  //writing and reading the same locations
  task write_read(
    input bit [31:0] addr,
    input bit [7:0]  len,
    input bit [2:0]  size,
    input bit [31:0] data
  );

    send_write(addr, len, size, data);
    send_read(addr, len, size);
  endtask

  //smoke scenario used by full test
  task smoke_scenario();
    write_read(
      32'h0000_0100, 8'd0, 3'd2, 32'h5049_5841
    );
  endtask

  //four beat burst scenario
  task burst_scenario();

    //using the exact values from saved burst waveform
    //31495841, 32495841, 33495841, 34495841
    send_write(
      32'h0000_0200,
      8'd3,
      3'd2,
      32'h3149_5841,
      4'hF,
      2'b01,
      4'h1,
      32'h0100_0000
    );

    send_read(32'h0000_0200, 8'd3, 3'd2);
  endtask

  //narrow transfer and strobe scenarios
  task narrow_scenario();

    //initializing surrounding words
    send_write(
      32'h0000_1200, 8'd3, 3'd2, 32'hA5A5_A5A5
    );

    //writing one byte into each lane
    for (int lane = 0; lane < 4; lane++) begin
      send_write(
        32'h0000_1200 + lane,
        8'd0,
        3'd0,
        32'h4433_2211
      );

      //checking updated and preserved bytes
      send_read(32'h0000_1200, 8'd0, 3'd2);
    end

    //aligned halfword transfer
    write_read(
      32'h0000_1204, 8'd0, 3'd1, 32'h0000_BEEF
    );

    send_read(32'h0000_1204, 8'd0, 3'd2);

    //unaligned halfword burst
    write_read(
      32'h0000_1209, 8'd2, 3'd1, 32'hB2A1_9080
    );

    //checking surrounding words with full width reads
    send_read(32'h0000_1208, 8'd1, 3'd2);

    //initializing memory for unaligned word burst
    send_write(
      32'h0000_1240, 8'd1, 3'd2, 32'h5555_AAAA
    );

    //partial first beat followed by aligned beat
    write_read(
      32'h0000_1241, 8'd1, 3'd2, 32'h8765_4321
    );

    send_read(32'h0000_1240, 8'd1, 3'd2);

    //checking all sixteen strobe patterns
    for (int s = 0; s < 16; s++) begin

      //restoring known data before partial write
      send_write(
        32'h0000_1280, 8'd0, 3'd2, 32'hA5A5_A5A5
      );

      send_write(
        32'h0000_1280, 8'd0, 3'd2, 32'h5A5A_5A5A,
        s[3:0]
      );

      send_read(32'h0000_1280, 8'd0, 3'd2);
    end
  endtask

  //memory and page boundary scenarios
  task boundary_scenario();

    //first valid word
    write_read(
      32'h0000_0000, 8'd0, 3'd2, 32'h1234_5678
    );

    for (int page = 1; page < 4; page++) begin

      //ending a burst at the page boundary
      write_read(
        (page * 4096) - 16,
        8'd3,
        3'd2,
        32'hABCD_0000 + page
      );

      //starting a transaction at the next page
      write_read(
        page * 4096,
        8'd0,
        3'd2,
        32'hDCBA_0000 + page
      );
    end

    //maximum burst ending at memory boundary
    write_read(
      32'h0000_3C00, 8'd255, 3'd2, 32'h2560_0000
    );

    //last valid word
    write_read(
      32'h0000_3FFC, 8'd0, 3'd2, 32'hCAFE_BABE
    );

    //last valid halfword
    write_read(
      32'h0000_3FFE, 8'd0, 3'd1, 32'hABCD_0000
    );

    //last valid byte
    write_read(
      32'h0000_3FFF, 8'd0, 3'd0, 32'hEF00_0000
    );

    //checking complete final word
    send_read(32'h0000_3FFC, 8'd0, 3'd2);
  endtask

  //unsupported command and invalid address scenarios
  task error_scenario();

    bit [1:0] bad_burst;

    //initializing memory before rejected writes
    send_write(
      32'h0000_2000, 8'd3, 3'd2, 32'h1122_3344
    );

    for (int i = 0; i < 3; i++) begin

      //selecting FIXED, WRAP and reserved burst types
      case (i)
        0: bad_burst = 2'b00;
        1: bad_burst = 2'b10;
        2: bad_burst = 2'b11;
      endcase

      //expecting SLVERR for unsupported commands
      send_write(
        32'h0000_2000, 8'd3, 3'd2, 32'hDEAD_BEEF,
        4'hF, bad_burst
      );

      send_read(
        32'h0000_2000, 8'd3, 3'd2, bad_burst
      );

      //checking rejected write preserved memory
      send_read(32'h0000_2000, 8'd3, 3'd2);
    end

    //transfer size larger than our data bus
    send_write(
      32'h0000_2000, 8'd0, 3'd3, 32'hFFFF_FFFF
    );

    send_read(32'h0000_2000, 8'd0, 3'd3);

    //checking memory after rejected size
    send_read(32'h0000_2000, 8'd3, 3'd2);

    //initializing address zero
    send_write(
      32'h0000_0000, 8'd0, 3'd2, 32'h1357_2468
    );

    //accessing outside the 16KB memory
    send_write(
      32'h0000_4000, 8'd0, 3'd2, 32'hFFFF_FFFF
    );

    send_read(32'h0000_4000, 8'd0, 3'd2);

    //checking invalid address did not wrap to zero
    send_read(32'h0000_0000, 8'd0, 3'd2);

    //checking normal operation after errors
    write_read(
      32'h0000_3000, 8'd0, 3'd2, 32'hABCD_1234
    );
  endtask

  //constrained random scenarios
  task random_scenario();

    bit [31:0] addr;
    bit [7:0]  len;
    bit [2:0]  size;
    bit [3:0]  wr_id;
    bit [3:0]  rd_id;

    int unsigned num_transactions;

    num_transactions = 100;

    //getting transaction count from run options
    if ($value$plusargs("N_TXNS=%d", num_transactions)) begin
      `uvm_info("RANDOM_TEST",
        $sformatf("Requested pairs = %0d", num_transactions),
        UVM_LOW)
    end

    if (num_transactions == 0)
      `uvm_fatal("RANDOM_TEST", "N_TXNS must be greater than zero")

    //initializing memory before random partial writes
    for (int block_no = 0; block_no < 16; block_no++) begin
      send_write(
        block_no * 1024,
        8'd255,
        3'd2,
        32'hA5A5_0000 + block_no
      );
    end

    repeat (num_transactions) begin

      //randomizing legal command values
      if (!std::randomize(addr, len, size, wr_id, rd_id) with {

        size inside {[0:2]};

        len dist {
          0        := 10,
          1        := 10,
          3        := 10,
          15       := 10,
          255      := 10,
          2        := 5,
          [4:14]   :/ 15,
          [16:254] :/ 30
        };

        addr inside {[32'h0000_0000:32'h0000_3FFF]};

        //keeping burst inside memory
        ((addr >> size) << size) +
          ((int'(len) + 1) << size) <= 16384;

        //keeping burst inside its 4KB page
        (((addr & 32'hFFF) >> size) << size) +
          ((int'(len) + 1) << size) <= 4096;

      }) begin
        `uvm_fatal("RANDOM_TEST", "Command randomization failed")
      end

      //generating random data and legal random strobes
      send_write(
        addr, len, size, 32'd0,
        4'hF, 2'b01, wr_id, 32'd1, 1'b1
      );

      //reading back the written locations
      send_read(addr, len, size, 2'b01, rd_id);
    end
  endtask

endclass
