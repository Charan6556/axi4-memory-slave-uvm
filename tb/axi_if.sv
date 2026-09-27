interface axi_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4
)(
    input logic ACLK,
    input logic ARESETn
);

    localparam int STRB_WIDTH = DATA_WIDTH / 8;

    // Write address channel
    logic [ID_WIDTH-1:0]   AWID;
    logic [ADDR_WIDTH-1:0] AWADDR;
    logic [7:0]            AWLEN;
    logic [2:0]            AWSIZE;
    logic [1:0]            AWBURST;
    logic                  AWVALID;
    logic                  AWREADY;

    // Write data channel
    logic [DATA_WIDTH-1:0] WDATA;
    logic [STRB_WIDTH-1:0] WSTRB;
    logic                  WLAST;
    logic                  WVALID;
    logic                  WREADY;

    // Write response channel
    logic [ID_WIDTH-1:0]   BID;
    logic [1:0]            BRESP;
    logic                  BVALID;
    logic                  BREADY;

    // Read address channel
    logic [ID_WIDTH-1:0]   ARID;
    logic [ADDR_WIDTH-1:0] ARADDR;
    logic [7:0]            ARLEN;
    logic [2:0]            ARSIZE;
    logic [1:0]            ARBURST;
    logic                  ARVALID;
    logic                  ARREADY;

    // Read data channel
    logic [ID_WIDTH-1:0]   RID;
    logic [DATA_WIDTH-1:0] RDATA;
    logic [1:0]            RRESP;
    logic                  RLAST;
    logic                  RVALID;
    logic                  RREADY;

      // Write driver clocking block
    clocking wr_cb @(posedge ACLK);
        default input #1step output #0;

        input ARESETn;

        output AWID, AWADDR, AWLEN, AWSIZE, AWBURST;
        output AWVALID;
        input  AWREADY;

        output WDATA, WSTRB, WLAST, WVALID;
        input  WREADY;

        input  BID, BRESP, BVALID;
        output BREADY;
    endclocking

    // Read driver clocking block
    clocking rd_cb @(posedge ACLK);
        default input #1step output #0;

        input ARESETn;

        output ARID, ARADDR, ARLEN, ARSIZE, ARBURST;
        output ARVALID;
        input  ARREADY;

        input  RID, RDATA, RRESP, RLAST, RVALID;
        output RREADY;
    endclocking

    //monitor clocking block
    clocking mon_cb @(posedge ACLK);
        default input #1step;

        input ARESETn;

        input AWID, AWADDR, AWLEN, AWSIZE, AWBURST;
        input AWVALID, AWREADY;

        input WDATA, WSTRB, WLAST, WVALID, WREADY;

        input BID, BRESP, BVALID, BREADY;

        input ARID, ARADDR, ARLEN, ARSIZE, ARBURST;
        input ARVALID, ARREADY;

        input RID, RDATA, RRESP, RLAST, RVALID, RREADY;
    endclocking

    modport MP_WDRV (clocking wr_cb);
    modport MP_RDRV (clocking rd_cb);
    modport MP_MON   (clocking mon_cb);

endinterface
