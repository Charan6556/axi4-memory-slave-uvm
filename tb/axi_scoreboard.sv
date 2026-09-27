class axi_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi_scoreboard)

  uvm_analysis_imp_wr #(axi_write_item, axi_scoreboard) wr_imp;
  uvm_analysis_imp_rd #(axi_read_item, axi_scoreboard) rd_imp;

  byte unsigned mem [longint unsigned];
  axi_write_item wr_cmd;
  axi_read_item rd_cmd;
  axi_write_item pending_writes[$];

  longint unsigned wr_addr, rd_addr, last_cycle;
  bit have_cycle, wr_busy, rd_busy, wr_error, wr_fault;
  int wr_count, rd_count;
  int writes = 0, reads = 0, skipped_bytes = 0;

  logic [31:0] expected_data;
  bit [31:0] compare_mask;
  bit [1:0] expected_resp;

  function new (string name = "axi_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    wr_imp = new("wr_imp", this);
    rd_imp = new("rd_imp", this);
  endfunction

  // Commit writes only after all observations from their edge can arrive
  function void flush_writes();
    foreach (pending_writes[i]) check_write(pending_writes[i]);
    pending_writes.delete();
  endfunction

  function void advance_cycle(longint unsigned cycle);
    if (have_cycle && cycle < last_cycle)
      `uvm_fatal("SB", "Monitor observations arrived out of order")
    if (have_cycle && cycle != last_cycle) flush_writes();
    last_cycle = cycle;
    have_cycle = 1;
  endfunction

  function void write_wr(axi_write_item item);
    advance_cycle(item.cycle);
    pending_writes.push_back(item);
  endfunction

  function void write_rd(axi_read_item item);
    advance_cycle(item.cycle);
    check_read(item);
  endfunction

  function longint unsigned next_addr(longint unsigned addr, bit [2:0] size);
    longint unsigned step;
    step = 64'd1 << size;
    return (addr / step + 1) * step;
  endfunction

  function bit access_ok(longint unsigned addr, bit [2:0] size, bit [1:0] burst);
    return burst == 2'b01 && size <= 2 &&
           addr < 64'h4000 && next_addr(addr, size) <= 64'h4000;
  endfunction

  function void check_write(axi_write_item item);
    longint unsigned byte_addr;
    case (item.event_kind)
      axi_write_item::WR_ADDR: begin
        if (wr_busy) `uvm_fatal("SB", "Overlapping write commands")
        wr_cmd = item;
        wr_addr = {32'b0, item.AWADDR};
        wr_count = 0;
        wr_busy = 1;
        wr_error = 0;
        wr_fault = 0;
      end
      axi_write_item::WR_BEAT: begin
        if (!wr_busy || wr_fault) `uvm_fatal("SB", "Unexpected write beat")
        if (item.WDATA.size() != 1 || item.WSTRB.size() != 1)
          `uvm_fatal("SB", "Write observation must contain one beat")
        if (item.beat_index != wr_count || wr_count > int'(wr_cmd.AWLEN))
          `uvm_fatal("SB", "Incorrect write beat count")
        if (item.WLAST !== (wr_count == int'(wr_cmd.AWLEN))) begin
          `uvm_error("SB", "Incorrect WLAST")
          wr_fault = 1;
          return;
        end
        if (!access_ok(wr_addr, wr_cmd.AWSIZE, wr_cmd.AWBURST)) wr_error = 1;
        else begin
          for (int lane = 0; lane < 4; lane++) begin
            byte_addr = (wr_addr / 4) * 4 + 64'(lane);
            if (byte_addr >= wr_addr && byte_addr < next_addr(wr_addr, wr_cmd.AWSIZE)
                && item.WSTRB[0][lane])
              mem[byte_addr] = item.WDATA[0][8*lane +: 8];
          end
        end
        wr_addr = next_addr(wr_addr, wr_cmd.AWSIZE);
        wr_count++;
      end
      axi_write_item::WR_RESP: begin
        if (!wr_busy) `uvm_fatal("SB", "B response without a command")
        if (wr_fault || wr_count != int'(wr_cmd.AWLEN) + 1)
          `uvm_error("SB", "Incomplete write burst")
        if (item.BID !== wr_cmd.AWID || item.BRESP !== (wr_error ? 2'b10 : 2'b00))
          `uvm_error("SB", $sformatf("Write response mismatch: BID=%h BRESP=%b", item.BID, item.BRESP))
        wr_busy = 0;
        writes++;
      end
      default: `uvm_fatal("SB", "Unknown write event")
    endcase
  endfunction

  // Snapshot the value the DUT should hold until the R handshake
  function void prepare_read();
    longint unsigned byte_addr;
    expected_data = '0;
    compare_mask = '1;
    expected_resp = 2'b10;
    if (access_ok(rd_addr, rd_cmd.ARSIZE, rd_cmd.ARBURST)) begin
      expected_resp = 2'b00;
      for (int lane = 0; lane < 4; lane++) begin
        byte_addr = (rd_addr / 4) * 4 + 64'(lane);
        if (byte_addr >= rd_addr && byte_addr < next_addr(rd_addr, rd_cmd.ARSIZE)) begin
          if (mem.exists(byte_addr) != 0) expected_data[8*lane +: 8] = mem[byte_addr];
          else compare_mask[8*lane +: 8] = '0;
        end
      end
    end
  endfunction

  function void check_read(axi_read_item item);
    case (item.event_kind)
      axi_read_item::RD_ADDR: begin
        if (rd_busy) `uvm_fatal("SB", "Overlapping read commands")
        rd_cmd = item;
        rd_addr = {32'b0, item.ARADDR};
        rd_count = 0;
        rd_busy = 1;
        prepare_read();
      end
      axi_read_item::RD_BEAT: begin
        if (!rd_busy) `uvm_fatal("SB", "R beat without a command")
        if (item.RDATA.size() != 1 || item.RRESP.size() != 1 ||
            item.RID.size() != 1 || item.RLAST.size() != 1)
          `uvm_fatal("SB", "Read observation must contain one beat")
        if (item.beat_index != rd_count)
          `uvm_error("SB", "Incorrect read beat index")
        if (item.RID[0] !== rd_cmd.ARID || item.RRESP[0] !== expected_resp ||
            item.RLAST[0] !== (rd_count == int'(rd_cmd.ARLEN)))
          `uvm_error("SB", "Read ID, response, or LAST mismatch")
        if ((item.RDATA[0] & compare_mask) !== (expected_data & compare_mask))
          `uvm_error("SB_DATA", $sformatf("addr=%h beat=%0d expected=%h actual=%h mask=%h",
            rd_addr, rd_count, expected_data, item.RDATA[0], compare_mask))
        for (int lane = 0; lane < 4; lane++)
          if (compare_mask[8*lane +: 8] == 0) skipped_bytes++;
        rd_count++;
        if (rd_count == int'(rd_cmd.ARLEN) + 1) begin
          rd_busy = 0;
          reads++;
        end
        else begin
          rd_addr = next_addr(rd_addr, rd_cmd.ARSIZE);
          prepare_read();
        end
      end
      default: `uvm_fatal("SB", "Unknown read event")
    endcase
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    flush_writes();
    if (wr_busy || rd_busy) `uvm_error("SB", "Incomplete transaction at end of test")
    if (writes == 0 && reads == 0) `uvm_error("SB", "No completed transactions")
    if (skipped_bytes != 0)
      `uvm_warning("SB", $sformatf("Skipped %0d uninitialized bytes", skipped_bytes))
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", $sformatf("Writes=%0d reads=%0d skipped bytes=%0d",
      writes, reads, skipped_bytes), UVM_LOW)
  endfunction

endclass
