module axi_ucie_bridge #(
  parameter int ADDR_W = 32,
  parameter int DATA_W = 32,
  parameter int ID_W   = 4,
  parameter int FLIT_W = 128
) (
  input  logic                aclk,
  input  logic                aresetn,
  input  logic [ID_W-1:0]     s_axi_awid,
  input  logic [ADDR_W-1:0]   s_axi_awaddr,
  input  logic [7:0]          s_axi_awlen,
  input  logic [2:0]          s_axi_awsize,
  input  logic [1:0]          s_axi_awburst,
  input  logic                s_axi_awvalid,
  output logic                s_axi_awready,
  input  logic [DATA_W-1:0]   s_axi_wdata,
  input  logic [DATA_W/8-1:0] s_axi_wstrb,
  input  logic                s_axi_wlast,
  input  logic                s_axi_wvalid,
  output logic                s_axi_wready,
  output logic [ID_W-1:0]     s_axi_bid,
  output logic [1:0]          s_axi_bresp,
  output logic                s_axi_bvalid,
  input  logic                s_axi_bready,
  input  logic [ID_W-1:0]     s_axi_arid,
  input  logic [ADDR_W-1:0]   s_axi_araddr,
  input  logic [7:0]          s_axi_arlen,
  input  logic [2:0]          s_axi_arsize,
  input  logic [1:0]          s_axi_arburst,
  input  logic                s_axi_arvalid,
  output logic                s_axi_arready,
  output logic [ID_W-1:0]     s_axi_rid,
  output logic [DATA_W-1:0]   s_axi_rdata,
  output logic [1:0]          s_axi_rresp,
  output logic                s_axi_rlast,
  output logic                s_axi_rvalid,
  input  logic                s_axi_rready,
  output logic                ucie_tx_valid,
  input  logic                ucie_tx_ready,
  output logic [FLIT_W-1:0]   ucie_tx_data,
  input  logic                ucie_rx_valid,
  output logic                ucie_rx_ready,
  input  logic [FLIT_W-1:0]   ucie_rx_data
);

  localparam logic [3:0] OP_WRITE_REQ = 4'h1;
  localparam logic [3:0] OP_READ_REQ  = 4'h2;
  localparam logic [3:0] OP_WRITE_RSP = 4'h8;
  localparam logic [3:0] OP_READ_RSP  = 4'h9;

  logic [ID_W-1:0] awid_q;
  logic [ADDR_W-1:0] awaddr_q;
  logic [7:0] awlen_q;
  logic [2:0] awsize_q;
  logic [1:0] awburst_q;
  logic aw_hold_valid;

  logic [DATA_W-1:0] wdata_q;
  logic [DATA_W/8-1:0] wstrb_q;
  logic wlast_q;
  logic w_hold_valid;

  logic [ID_W-1:0] arid_q;
  logic [ADDR_W-1:0] araddr_q;
  logic [7:0] arlen_q;
  logic [2:0] arsize_q;
  logic [1:0] arburst_q;
  logic ar_hold_valid;

  logic write_inflight;
  logic read_inflight;

  logic tx_valid_q;
  logic [FLIT_W-1:0] tx_data_q;
  logic tx_is_write_q;

  logic [ID_W-1:0] bid_q;
  logic [1:0] bresp_q;
  logic bvalid_q;

  logic [ID_W-1:0] rid_q;
  logic [DATA_W-1:0] rdata_q;
  logic [1:0] rresp_q;
  logic rvalid_q;

  assign s_axi_awready = aresetn && !aw_hold_valid && !write_inflight;
  assign s_axi_wready  = aresetn && !w_hold_valid  && !write_inflight;
  assign s_axi_arready = aresetn && !ar_hold_valid && !read_inflight;

  assign s_axi_bid = bid_q;
  assign s_axi_bresp = bresp_q;
  assign s_axi_bvalid = bvalid_q;

  assign s_axi_rid = rid_q;
  assign s_axi_rdata = rdata_q;
  assign s_axi_rresp = rresp_q;
  assign s_axi_rlast = rvalid_q;
  assign s_axi_rvalid = rvalid_q;

  assign ucie_tx_valid = tx_valid_q;
  assign ucie_tx_data = tx_data_q;
  assign ucie_rx_ready = aresetn && !bvalid_q && !rvalid_q;

  function automatic logic [FLIT_W-1:0] pack_write_req;
    logic [FLIT_W-1:0] flit;
    begin
      flit = '0;
      flit[127:124] = OP_WRITE_REQ;
      flit[123:120] = awid_q[3:0];
      flit[119:88]  = awaddr_q[31:0];
      flit[87:56]   = wdata_q[31:0];
      flit[55:52]   = wstrb_q[3:0];
      flit[51:44]   = awlen_q;
      flit[43:41]   = awsize_q;
      flit[40:39]   = awburst_q;
      flit[38]      = wlast_q;
      return flit;
    end
  endfunction

  function automatic logic [FLIT_W-1:0] pack_read_req;
    logic [FLIT_W-1:0] flit;
    begin
      flit = '0;
      flit[127:124] = OP_READ_REQ;
      flit[123:120] = arid_q[3:0];
      flit[119:88]  = araddr_q[31:0];
      flit[51:44]   = arlen_q;
      flit[43:41]   = arsize_q;
      flit[40:39]   = arburst_q;
      return flit;
    end
  endfunction

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      awid_q <= '0;
      awaddr_q <= '0;
      awlen_q <= '0;
      awsize_q <= '0;
      awburst_q <= '0;
      aw_hold_valid <= 1'b0;
      wdata_q <= '0;
      wstrb_q <= '0;
      wlast_q <= 1'b0;
      w_hold_valid <= 1'b0;
      arid_q <= '0;
      araddr_q <= '0;
      arlen_q <= '0;
      arsize_q <= '0;
      arburst_q <= '0;
      ar_hold_valid <= 1'b0;
      write_inflight <= 1'b0;
      read_inflight <= 1'b0;
      tx_valid_q <= 1'b0;
      tx_data_q <= '0;
      tx_is_write_q <= 1'b0;
      bid_q <= '0;
      bresp_q <= '0;
      bvalid_q <= 1'b0;
      rid_q <= '0;
      rdata_q <= '0;
      rresp_q <= '0;
      rvalid_q <= 1'b0;
    end else begin
      if (s_axi_awvalid && s_axi_awready) begin
        awid_q <= s_axi_awid;
        awaddr_q <= s_axi_awaddr;
        awlen_q <= s_axi_awlen;
        awsize_q <= s_axi_awsize;
        awburst_q <= s_axi_awburst;
        aw_hold_valid <= 1'b1;
      end

      if (s_axi_wvalid && s_axi_wready) begin
        wdata_q <= s_axi_wdata;
        wstrb_q <= s_axi_wstrb;
        wlast_q <= s_axi_wlast;
        w_hold_valid <= 1'b1;
      end

      if (s_axi_arvalid && s_axi_arready) begin
        arid_q <= s_axi_arid;
        araddr_q <= s_axi_araddr;
        arlen_q <= s_axi_arlen;
        arsize_q <= s_axi_arsize;
        arburst_q <= s_axi_arburst;
        ar_hold_valid <= 1'b1;
      end

      if (!tx_valid_q) begin
        if (aw_hold_valid && w_hold_valid && !write_inflight) begin
          tx_valid_q <= 1'b1;
          tx_data_q <= pack_write_req();
          tx_is_write_q <= 1'b1;
        end else if (ar_hold_valid && !read_inflight) begin
          tx_valid_q <= 1'b1;
          tx_data_q <= pack_read_req();
          tx_is_write_q <= 1'b0;
        end
      end

      if (tx_valid_q && ucie_tx_ready) begin
        tx_valid_q <= 1'b0;
        if (tx_is_write_q) begin
          write_inflight <= 1'b1;
          aw_hold_valid <= 1'b0;
          w_hold_valid <= 1'b0;
        end else begin
          read_inflight <= 1'b1;
          ar_hold_valid <= 1'b0;
        end
      end

      if (ucie_rx_valid && ucie_rx_ready) begin
        unique case (ucie_rx_data[127:124])
          OP_WRITE_RSP: begin
            bid_q <= ucie_rx_data[123:120];
            bresp_q <= ucie_rx_data[55:54];
            bvalid_q <= 1'b1;
          end
          OP_READ_RSP: begin
            rid_q <= ucie_rx_data[123:120];
            rdata_q <= ucie_rx_data[87:56];
            rresp_q <= ucie_rx_data[55:54];
            rvalid_q <= 1'b1;
          end
          default: begin end
        endcase
      end

      if (bvalid_q && s_axi_bready) begin
        bvalid_q <= 1'b0;
        write_inflight <= 1'b0;
      end

      if (rvalid_q && s_axi_rready) begin
        rvalid_q <= 1'b0;
        read_inflight <= 1'b0;
      end
    end
  end

endmodule
