class axi_coverage extends uvm_component;
  `uvm_component_utils(axi_coverage)

  uvm_analysis_imp_wr #(axi_write_item, axi_coverage) wr_imp;
  uvm_analysis_imp_rd #(axi_read_item, axi_coverage) rd_imp;

  // Read and write command coverage
  covergroup cmd_cg with function sample(
    bit is_write, bit [31:0] addr, bit [7:0] len,
    bit [2:0] size, bit [1:0] burst
  );
    option.per_instance = 1;

    cp_direction: coverpoint is_write {
      bins read_cmd = {0};
      bins write_cmd = {1};
    }

    cp_addr: coverpoint addr {
      bins first_word = {[32'h0000:32'h0003]};
      bins middle = {[32'h0004:32'h3FFB]};
      bins last_word = {[32'h3FFC:32'h3FFF]};
      bins outside_mem = {[32'h4000:32'hFFFF_FFFF]};
    }

    cp_offset: coverpoint addr[1:0] {
      bins offsets[] = {[0:3]};
    }

    cp_len: coverpoint len {
      bins one = {0};
      bins two = {1};
      bins short_burst = {[2:14]};
      bins sixteen = {15};
      bins medium_burst = {[16:254]};
      bins maximum = {255};
    }

    cp_size: coverpoint size {
      bins one_byte = {0};
      bins two_bytes = {1};
      bins four_bytes = {2};
      bins unsupported = {[3:7]};
    }

    cp_burst: coverpoint burst {
      bins fixed_burst = {0};
      bins incr_burst = {1};
      bins wrap_burst = {2};
      bins reserved = {3};
    }

    direction_size: cross cp_direction, cp_size;
    direction_length: cross cp_direction, cp_len;
  endgroup

  // Accepted write data coverage
  covergroup data_cg with function sample(bit [3:0] strb, logic last);
    option.per_instance = 1;

    cp_strb: coverpoint strb {
      bins masks[] = {[0:15]};
    }

    cp_last: coverpoint last {
      bins nonfinal = {0};
      bins final_beat = {1};
    }
  endgroup

  // Accepted response coverage
  covergroup resp_cg with function sample(bit is_write, logic [1:0] resp);
    option.per_instance = 1;

    cp_direction: coverpoint is_write {
      bins read_resp = {0};
      bins write_resp = {1};
    }

    cp_resp: coverpoint resp {
      bins okay = {2'b00};
      bins slverr = {2'b10};
    }

    direction_response: cross cp_direction, cp_resp;
  endgroup

  // Constructor
  function new (string name = "axi_coverage", uvm_component parent = null);
    super.new(name, parent);
    cmd_cg = new();
    data_cg = new();
    resp_cg = new();
  endfunction

  // Build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    wr_imp = new("wr_imp", this);
    rd_imp = new("rd_imp", this);
  endfunction

  // Sample write observations
  function void write_wr(axi_write_item item);
    case (item.event_kind)
      axi_write_item::WR_ADDR:
        cmd_cg.sample(1'b1, item.AWADDR, item.AWLEN, item.AWSIZE, item.AWBURST);

      axi_write_item::WR_BEAT:
        data_cg.sample(item.WSTRB[0], item.WLAST);

      axi_write_item::WR_RESP:
        resp_cg.sample(1'b1, item.BRESP);
    endcase
  endfunction

  // Sample read observations
  function void write_rd(axi_read_item item);
    case (item.event_kind)
      axi_read_item::RD_ADDR:
        cmd_cg.sample(1'b0, item.ARADDR, item.ARLEN, item.ARSIZE, item.ARBURST);

      axi_read_item::RD_BEAT:
        resp_cg.sample(1'b0, item.RRESP[0]);
    endcase
  endfunction

  // Report coverage
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info("COV", $sformatf(
      "Commands=%0.2f%% write data=%0.2f%% responses=%0.2f%%",
      cmd_cg.get_inst_coverage(),
      data_cg.get_inst_coverage(),
      resp_cg.get_inst_coverage()), UVM_LOW)
  endfunction

endclass
