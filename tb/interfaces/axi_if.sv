interface axi_if #(
  parameter int ID_W   = 4,
  parameter int ADDR_W = 32,
  parameter int DATA_W = 32
) (
  input logic aclk,
  input logic aresetn
);
  localparam int STRB_W = DATA_W/8;

  logic [ID_W-1:0]   awid;
  logic [ADDR_W-1:0] awaddr;
  logic [7:0]        awlen;
  logic [2:0]        awsize;
  logic [1:0]        awburst;
  logic              awvalid;
  logic              awready;

  logic [DATA_W-1:0] wdata;
  logic [STRB_W-1:0] wstrb;
  logic              wlast;
  logic              wvalid;
  logic              wready;

  logic [ID_W-1:0]   bid;
  logic [1:0]        bresp;
  logic              bvalid;
  logic              bready;

  logic [ID_W-1:0]   arid;
  logic [ADDR_W-1:0] araddr;
  logic [7:0]        arlen;
  logic [2:0]        arsize;
  logic [1:0]        arburst;
  logic              arvalid;
  logic              arready;

  logic [ID_W-1:0]   rid;
  logic [DATA_W-1:0] rdata;
  logic [1:0]        rresp;
  logic              rlast;
  logic              rvalid;
  logic              rready;

  modport master (
    input  aclk, aresetn,
    input  awready, wready, bid, bresp, bvalid,
    input  arready, rid, rdata, rresp, rlast, rvalid,
    output awid, awaddr, awlen, awsize, awburst, awvalid,
    output wdata, wstrb, wlast, wvalid, bready,
    output arid, araddr, arlen, arsize, arburst, arvalid, rready
  );

  modport slave (
    input  aclk, aresetn,
    input  awid, awaddr, awlen, awsize, awburst, awvalid,
    input  wdata, wstrb, wlast, wvalid, bready,
    input  arid, araddr, arlen, arsize, arburst, arvalid, rready,
    output awready, wready, bid, bresp, bvalid,
    output arready, rid, rdata, rresp, rlast, rvalid
  );

  modport monitor (
    input aclk, aresetn,
    input awid, awaddr, awlen, awsize, awburst, awvalid, awready,
    input wdata, wstrb, wlast, wvalid, wready,
    input bid, bresp, bvalid, bready,
    input arid, araddr, arlen, arsize, arburst, arvalid, arready,
    input rid, rdata, rresp, rlast, rvalid, rready
  );
endinterface
