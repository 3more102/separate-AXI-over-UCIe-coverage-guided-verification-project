module axi_ucie_bridge #(
  parameter int ADDR_W = 32,
  parameter int DATA_W = 64,
  parameter int ID_W   = 4
) (
  input  logic                  clk,
  input  logic                  rst_n,

  input  logic [ID_W-1:0]       s_axi_awid,
  input  logic [ADDR_W-1:0]     s_axi_awaddr,
  input  logic [7:0]            s_axi_awlen,
  input  logic [2:0]            s_axi_awsize,
  input  logic [1:0]            s_axi_awburst,
  input  logic                  s_axi_awvalid,
  output logic                  s_axi_awready,

  input  logic [DATA_W-1:0]     s_axi_wdata,
  input  logic [DATA_W/8-1:0]   s_axi_wstrb,
  input  logic                  s_axi_wlast,
  input  logic                  s_axi_wvalid,
  output logic                  s_axi_wready,

  output logic [ID_W-1:0]       s_axi_bid,
  output logic [1:0]            s_axi_bresp,
  output logic                  s_axi_bvalid,
  input  logic                  s_axi_bready,

  input  logic [ID_W-1:0]       s_axi_arid,
  input  logic [ADDR_W-1:0]     s_axi_araddr,
  input  logic [7:0]            s_axi_arlen,
  input  logic [2:0]            s_axi_arsize,
  input  logic [1:0]            s_axi_arburst,
  input  logic                  s_axi_arvalid,
  output logic                  s_axi_arready,

  output logic [ID_W-1:0]       s_axi_rid,
  output logic [DATA_W-1:0]     s_axi_rdata,
  output logic [1:0]            s_axi_rresp,
  output logic                  s_axi_rlast,
  output logic                  s_axi_rvalid,
  input  logic                  s_axi_rready,

  output logic                  link_req_valid,
  input  logic                  link_req_ready,
  output logic                  link_req_write,
  output logic [ID_W-1:0]       link_req_id,
  output logic [ADDR_W-1:0]     link_req_addr,
  output logic [7:0]            link_req_len,
  output logic [2:0]            link_req_size,
  output logic [DATA_W-1:0]     link_req_wdata,
  output logic [DATA_W/8-1:0]   link_req_wstrb,

  input  logic                  link_rsp_valid,
  output logic                  link_rsp_ready,
  input  logic                  link_rsp_write,
  input  logic [ID_W-1:0]       link_rsp_id,
  input  logic [1:0]            link_rsp_resp,
  input  logic [DATA_W-1:0]     link_rsp_rdata
);

  localparam logic [1:0] RESP_SLVERR = 2'b10;

  logic                aw_full;
  logic [ID_W-1:0]     aw_id_q;
  logic [ADDR_W-1:0]   aw_addr_q;
  logic [7:0]          aw_len_q;
  logic [2:0]          aw_size_q;
  logic [1:0]          aw_burst_q;

  logic                w_full;
  logic [DATA_W-1:0]   w_data_q;
  logic [DATA_W/8-1:0] w_strb_q;
  logic                w_last_q;

  logic                ar_full;
  logic [ID_W-1:0]     ar_id_q;
  logic [ADDR_W-1:0]   ar_addr_q;
  logic [7:0]          ar_len_q;
  logic [2:0]          ar_size_q;
  logic [1:0]          ar_burst_q;

  logic                inflight;

  assign s_axi_awready = rst_n && !aw_full;
  assign s_axi_wready  = rst_n && !w_full;
  assign s_axi_arready = rst_n && !ar_full;

  assign link_rsp_ready =
      rst_n && inflight &&
      ((link_rsp_write && !s_axi_bvalid) ||
       (!link_rsp_write && !s_axi_rvalid));

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_full        <= 1'b0;
      w_full         <= 1'b0;
      ar_full        <= 1'b0;
      inflight       <= 1'b0;
      link_req_valid <= 1'b0;
      link_req_write <= 1'b0;
      link_req_id    <= '0;
      link_req_addr  <= '0;
      link_req_len   <= '0;
      link_req_size  <= '0;
      link_req_wdata <= '0;
      link_req_wstrb <= '0;
      s_axi_bid      <= '0;
      s_axi_bresp    <= '0;
      s_axi_bvalid   <= 1'b0;
      s_axi_rid      <= '0;
      s_axi_rdata    <= '0;
      s_axi_rresp    <= '0;
      s_axi_rlast    <= 1'b0;
      s_axi_rvalid   <= 1'b0;
    end else begin
      if (s_axi_bvalid && s_axi_bready)
        s_axi_bvalid <= 1'b0;

      if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
        s_axi_rlast  <= 1'b0;
      end

      if (s_axi_awvalid && s_axi_awready) begin
        aw_full    <= 1'b1;
        aw_id_q    <= s_axi_awid;
        aw_addr_q  <= s_axi_awaddr;
        aw_len_q   <= s_axi_awlen;
        aw_size_q  <= s_axi_awsize;
        aw_burst_q <= s_axi_awburst;
      end

      if (s_axi_wvalid && s_axi_wready) begin
        w_full   <= 1'b1;
        w_data_q <= s_axi_wdata;
        w_strb_q <= s_axi_wstrb;
        w_last_q <= s_axi_wlast;
      end

      if (s_axi_arvalid && s_axi_arready) begin
        ar_full    <= 1'b1;
        ar_id_q    <= s_axi_arid;
        ar_addr_q  <= s_axi_araddr;
        ar_len_q   <= s_axi_arlen;
        ar_size_q  <= s_axi_arsize;
        ar_burst_q <= s_axi_arburst;
      end

      if (link_req_valid && link_req_ready) begin
        link_req_valid <= 1'b0;
        inflight       <= 1'b1;
      end

      if (link_rsp_valid && link_rsp_ready) begin
        inflight <= 1'b0;
        if (link_rsp_write) begin
          s_axi_bid    <= link_rsp_id;
          s_axi_bresp  <= link_rsp_resp;
          s_axi_bvalid <= 1'b1;
        end else begin
          s_axi_rid    <= link_rsp_id;
          s_axi_rdata  <= link_rsp_rdata;
          s_axi_rresp  <= link_rsp_resp;
          s_axi_rlast  <= 1'b1;
          s_axi_rvalid <= 1'b1;
        end
      end

      if (!link_req_valid && !inflight && !s_axi_bvalid && !s_axi_rvalid) begin
        if (aw_full && w_full) begin
          aw_full <= 1'b0;
          w_full  <= 1'b0;

          if ((aw_len_q != 8'd0) || !w_last_q) begin
            s_axi_bid    <= aw_id_q;
            s_axi_bresp  <= RESP_SLVERR;
            s_axi_bvalid <= 1'b1;
          end else begin
            link_req_valid <= 1'b1;
            link_req_write <= 1'b1;
            link_req_id    <= aw_id_q;
            link_req_addr  <= aw_addr_q;
            link_req_len   <= aw_len_q;
            link_req_size  <= aw_size_q;
            link_req_wdata <= w_data_q;
            link_req_wstrb <= w_strb_q;
          end
        end else if (ar_full) begin
          ar_full <= 1'b0;

          if (ar_len_q != 8'd0) begin
            s_axi_rid    <= ar_id_q;
            s_axi_rdata  <= '0;
            s_axi_rresp  <= RESP_SLVERR;
            s_axi_rlast  <= 1'b1;
            s_axi_rvalid <= 1'b1;
          end else begin
            link_req_valid <= 1'b1;
            link_req_write <= 1'b0;
            link_req_id    <= ar_id_q;
            link_req_addr  <= ar_addr_q;
            link_req_len   <= ar_len_q;
            link_req_size  <= ar_size_q;
            link_req_wdata <= '0;
            link_req_wstrb <= '0;
          end
        end
      end
    end
  end

  // Burst type is captured for future multi-beat support. The milestone-1
  // datapath accepts single-beat requests only.
  logic _unused;
  always_comb _unused = ^{aw_burst_q, ar_burst_q};

endmodule
