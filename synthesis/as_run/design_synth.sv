`timescale 1ns/1ps
module axi4_mem_slave #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4
)(
    input  logic                      ACLK,
    input  logic                      ARESETn,

    // Write address channel
    input  logic [ID_WIDTH-1:0]       AWID,
    input  logic [ADDR_WIDTH-1:0]     AWADDR,
    input  logic [7:0]                AWLEN,
    input  logic [2:0]                AWSIZE,
    input  logic [1:0]                AWBURST,
    input  logic                      AWVALID,
    output logic                      AWREADY,

    // Write data channel
    input  logic [DATA_WIDTH-1:0]     WDATA,
    input  logic [(DATA_WIDTH/8)-1:0] WSTRB,
    input  logic                      WLAST,
    input  logic                      WVALID,
    output logic                      WREADY,

    // Write response channel
    output logic [ID_WIDTH-1:0]       BID,
    output logic [1:0]                BRESP,
    output logic                      BVALID,
    input  logic                      BREADY,

    // Read address channel
    input  logic [ID_WIDTH-1:0]       ARID,
    input  logic [ADDR_WIDTH-1:0]     ARADDR,
    input  logic [7:0]                ARLEN,
    input  logic [2:0]                ARSIZE,
    input  logic [1:0]                ARBURST,
    input  logic                      ARVALID,
    output logic                      ARREADY,

    // Read data channel
    output logic [ID_WIDTH-1:0]       RID,
    output logic [DATA_WIDTH-1:0]     RDATA,
    output logic [1:0]                RRESP,
    output logic                      RLAST,
    output logic                      RVALID,
    input  logic                      RREADY
);

    // Memory configuration
    localparam int MEM_BYTES        = 16 * 1024;
    localparam int BYTES_PER_WORD   = DATA_WIDTH / 8;
    localparam int MEM_DEPTH        = 64;
    localparam int BYTE_OFFSET_BITS = $clog2(BYTES_PER_WORD);  // addr >> this = word index
    localparam int MAX_SIZE         = $clog2(BYTES_PER_WORD);  // largest legal AxSIZE

    localparam logic [1:0] BURST_INCR  = 2'b01;
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    // One bit wider than ADDR_WIDTH so next_addr and the range check can run
    // past the top of the address space without wrapping.
    typedef logic [ADDR_WIDTH:0] addr_t;

    logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // synthesis translate_off
    initial begin
        for (int i = 0; i < MEM_DEPTH; i++) mem[i] = '0;
    end
    // synthesis translate_on

    // Write controller registers
    typedef enum logic [1:0] {
        WR_IDLE, WR_DATA, WR_RESP
    } wr_state_t;

    wr_state_t           wr_state;
    logic [ID_WIDTH-1:0] wr_id;
    addr_t               wr_addr;        // address of the current beat
    logic [2:0]          wr_size;
    logic [8:0]          wr_beats_left;  // 9 bits: AWLEN+1 can be 256
    logic                wr_cmd_error;   // unsupported command: block all writes
    logic                wr_error;       // sticky: drives BRESP

    // Read controller registers
    typedef enum logic {
        RD_IDLE, RD_DATA
    } rd_state_t;

    rd_state_t           rd_state;
    logic [ID_WIDTH-1:0] rd_id;
    addr_t               rd_addr;
    logic [2:0]          rd_size;
    logic [8:0]          rd_beats_left;
    logic                rd_cmd_error;   // no sticky flag: RRESP is per beat

    // Handshake outputs depend on registered state only, never on the
    // incoming VALID of the same channel.
    assign AWREADY = ARESETn && (wr_state == WR_IDLE);
    assign WREADY  = ARESETn && (wr_state == WR_DATA);
    assign BVALID  = ARESETn && (wr_state == WR_RESP);
    assign BID     = wr_id;
    assign BRESP   = wr_error ? RESP_SLVERR : RESP_OKAY;

    assign ARREADY = ARESETn && (rd_state == RD_IDLE);
    assign RVALID  = ARESETn && (rd_state == RD_DATA);
    assign RID     = rd_id;
    assign RLAST   = RVALID && (rd_beats_left == 9'd1);

    // helpers

    // Supported command: INCR burst, transfer no wider than the bus.
    function automatic logic command_ok(
        input logic [1:0] burst,
        input logic [2:0] size
    );
        return (burst == BURST_INCR) && (int'(size) <= MAX_SIZE);
    endfunction

    // INCR rule: align the current address down to the transfer size, then add it.
    function automatic addr_t next_addr(
        input addr_t      addr,
        input logic [2:0] size
    );
        addr_t step;
        step = addr_t'(1) << size;
        return (addr & ~(step - addr_t'(1))) + step;
    endfunction

    // Both the first and last byte of the beat must lie inside the memory.
    function automatic logic beat_in_range(
        input addr_t      addr,
        input logic [2:0] size
    );
        addr_t last_byte;
        if (int'(size) > MAX_SIZE)
            return 1'b0;
        last_byte = next_addr(addr, size) - addr_t'(1);
        return (addr < addr_t'(MEM_BYTES)) &&
               (last_byte < addr_t'(MEM_BYTES));
    endfunction

    // Byte lanes this beat may use: a contiguous run inside one aligned container.
    function automatic logic [BYTES_PER_WORD-1:0] byte_mask(
        input addr_t      addr,
        input logic [2:0] size
    );
        logic [BYTES_PER_WORD-1:0] mask;
        int unsigned transfer_bytes, first_lane, last_lane;
        mask = '0;
        if (int'(size) <= MAX_SIZE) begin
            transfer_bytes = 1 << size;
            first_lane = int'(addr % addr_t'(BYTES_PER_WORD));
            last_lane  = (first_lane & ~(transfer_bytes - 1)) +
                         transfer_bytes - 1;
            for (int lane = 0; lane < BYTES_PER_WORD; lane++)
                if (lane >= first_lane && lane <= last_lane)
                    mask[lane] = 1'b1;
        end
        return mask;
    endfunction

    // Read data, zeroed on lanes this beat does not cover.
    function automatic logic [DATA_WIDTH-1:0] read_beat(
        input addr_t      addr,
        input logic [2:0] size
    );
        logic [DATA_WIDTH-1:0]     data;
        logic [BYTES_PER_WORD-1:0] mask;
        data = '0;
        if (beat_in_range(addr, size)) begin
            mask = byte_mask(addr, size);
            for (int lane = 0; lane < BYTES_PER_WORD; lane++)
                if (mask[lane])
                    data[8*lane +: 8] =
                        mem[int'(addr >> BYTE_OFFSET_BITS)][8*lane +: 8];
        end
        return data;
    endfunction

    // per-beat combinational values

    logic                      wr_range_ok;
    logic [BYTES_PER_WORD-1:0] wr_mask;
    logic                      w_beat_accepted;
    addr_t                     rd_next_addr;

    assign wr_range_ok     = beat_in_range(wr_addr, wr_size);
    assign wr_mask         = byte_mask(wr_addr, wr_size);
    assign w_beat_accepted = WVALID && WREADY;
    assign rd_next_addr    = next_addr(rd_addr, rd_size);

    // write path

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            wr_state      <= WR_IDLE;
            wr_id         <= '0;
            wr_addr       <= '0;
            wr_size       <= '0;
            wr_beats_left <= '0;
            wr_cmd_error  <= 1'b0;
            wr_error      <= 1'b0;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    if (AWVALID && AWREADY) begin
                        wr_id         <= AWID;
                        wr_addr       <= {1'b0, AWADDR};
                        wr_size       <= AWSIZE;
                        wr_beats_left <= {1'b0, AWLEN} + 9'd1;
                        wr_cmd_error  <= !command_ok(AWBURST, AWSIZE);
                        wr_error      <= !command_ok(AWBURST, AWSIZE);
                        wr_state      <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    if (w_beat_accepted) begin
                        // Flag a bad WLAST or an out-of-range beat, but keep
                        // counting from AWLEN so the burst always completes.
                        if ((WLAST != (wr_beats_left == 9'd1)) || !wr_range_ok)
                            wr_error <= 1'b1;

                        if (wr_beats_left == 9'd1) begin
                            wr_beats_left <= '0;
                            wr_state      <= WR_RESP;
                        end else begin
                            wr_beats_left <= wr_beats_left - 9'd1;
                            if (!wr_cmd_error)
                                wr_addr <= next_addr(wr_addr, wr_size);
                        end
                    end
                end

                WR_RESP: begin
                    if (BVALID && BREADY)
                        wr_state <= WR_IDLE;
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // Memory write kept out of the FSM block so a RAM can be inferred cleanly.
    always_ff @(posedge ACLK) begin
        if (w_beat_accepted && !wr_cmd_error && wr_range_ok) begin
            for (int lane = 0; lane < BYTES_PER_WORD; lane++)
                if (WSTRB[lane] && wr_mask[lane])
                    mem[int'(wr_addr >> BYTE_OFFSET_BITS)][8*lane +: 8]
                        <= WDATA[8*lane +: 8];
        end
    end

    //Read path
    // Data is fetched one beat ahead so RVALID never covers stale data.

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            rd_state      <= RD_IDLE;
            rd_id         <= '0;
            rd_addr       <= '0;
            rd_size       <= '0;
            rd_beats_left <= '0;
            rd_cmd_error  <= 1'b0;
            RDATA         <= '0;
            RRESP         <= RESP_OKAY;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    if (ARVALID && ARREADY) begin
                        rd_id         <= ARID;
                        rd_addr       <= {1'b0, ARADDR};
                        rd_size       <= ARSIZE;
                        rd_beats_left <= {1'b0, ARLEN} + 9'd1;
                        rd_cmd_error  <= !command_ok(ARBURST, ARSIZE);
                        rd_state      <= RD_DATA;

                        if (command_ok(ARBURST, ARSIZE) &&
                            beat_in_range({1'b0, ARADDR}, ARSIZE)) begin
                            RDATA <= read_beat({1'b0, ARADDR}, ARSIZE);
                            RRESP <= RESP_OKAY;
                        end else begin
                            RDATA <= '0;
                            RRESP <= RESP_SLVERR;
                        end
                    end
                end

                RD_DATA: begin
                    if (RVALID && RREADY) begin
                        if (rd_beats_left == 9'd1) begin
                            rd_beats_left <= '0;
                            rd_state      <= RD_IDLE;
                        end else begin
                            rd_beats_left <= rd_beats_left - 9'd1;
                            if (!rd_cmd_error)
                                rd_addr <= rd_next_addr;

                            if (!rd_cmd_error &&
                                beat_in_range(rd_next_addr, rd_size)) begin
                                RDATA <= read_beat(rd_next_addr, rd_size);
                                RRESP <= RESP_OKAY;
                            end else begin
                                RDATA <= '0;
                                RRESP <= RESP_SLVERR;
                            end
                        end
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

endmodule
