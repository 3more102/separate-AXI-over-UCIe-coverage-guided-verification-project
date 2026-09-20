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

  localparam logic [1:0] RESP_OKAY   = 2'b00;
  localparam logic [1:0] RESP_SLVERR = 2'b10;
  localparam logic [1:0] BURST_FIXED = 2'b00;
  localparam logic [1:0] BURST_INCR  = 2'b01;
  localparam int MAX_SIZE = $clog2(DATA_W/8);

  logic                aw_full;
  logic [ID_W-1:0]     aw_id_q;
  logic [ADDR_W-1:0]   aw_addr_q;
  logic [7:0]          aw_len_q;
  logic [2:0]          aw_size_q;
  logic [1:0]          aw_burst_q;
  logic [8:0]          wr_beats_left;
  logic                wr_meta_error;
  logic [1:0]          wr_resp_accum;

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
  logic [8:0]          rd_beats_left;
  logic                rd_meta_error;

  logic                inflight;
  logic                inflight_write;
  logic                inflight_last;
  logic                inflight_protocol_error;

  function automatic logic [ADDR_W-1:0] incr_addr(
    input logic [ADDR_W-1:0] addr,
    input logic [2:0] size
  );
    logic [ADDR_W-1:0] step;
    begin
      step = {{(ADDR_W-1){1'b0}}, 1'b1} << size;
      incr_addr = addr + step;
    end
  endfunction

  assign s_axi_awready = rst_n && !aw_full;
  assign s_axi_wready  = rst_n && !w_full;
  assign s_axi_arready = rst_n && !ar_full;

  assign link_rsp_ready =
      rst_n && inflight &&
      ((inflight_write && !s_axi_bvalid) ||
       (!inflight_write && !s_axi_rvalid));

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_full                  <= 1'b0;
      aw_id_q                  <= '0;
      aw_addr_q                <= '0;
      aw_len_q                 <= '0;
      aw_size_q                <= '0;
      aw_burst_q               <= '0;
      wr_beats_left            <= '0;
      wr_meta_error            <= 1'b0;
      wr_resp_accum            <= RESP_OKAY;

      w_full                   <= 1'b0;
      w_data_q                 <= '0;
      w_strb_q                 <= '0;
      w_last_q                 <= 1'b0;

      ar_full                  <= 1'b0;
      ar_id_q                  <= '0;
      ar_addr_q                <= '0;
      ar_len_q                 <= '0;
      ar_size_q                <= '0;
      ar_burst_q               <= '0;
      rd_beats_left            <= '0;
      rd_meta_error            <= 1'b0;

      inflight                 <= 1'b0;
      inflight_write           <= 1'b0;
      inflight_last            <= 1'b0;
      inflight_protocol_error  <= 1'b0;

      link_req_valid           <= 1'b0;
      link_req_write           <= 1'b0;
      link_req_id              <= '0;
      link_req_addr            <= '0;
      link_req_len             <= '0;
      link_req_size            <= '0;
      link_req_wdata           <= '0;
      link_req_wstrb           <= '0;

      s_axi_bid                <= '0;
      s_axi_bresp              <= RESP_OKAY;
      s_axi_bvalid             <= 1'b0;
      s_axi_rid                <= '0;
      s_axi_rdata              <= '0;
      s_axi_rresp              <= RESP_OKAY;
      s_axi_rlast              <= 1'b0;
      s_axi_rvalid             <= 1'b0;
    end else begin
      if (s_axi_bvalid && s_axi_bready)
        s_axi_bvalid <= 1'b0;

      if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
        s_axi_rlast  <= 1'b0;

        if (rd_beats_left == 9'd1) begin
          ar_full       <= 1'b0;
          rd_beats_left <= '0;
        end else begin
          rd_beats_left <= rd_beats_left - 9'd1;
          if (ar_burst_q == BURST_INCR)
            ar_addr_q <= incr_addr(ar_addr_q, ar_size_q);
        end
      end

      if (s_axi_awvalid && s_axi_awready) begin
        aw_full       <= 1'b1;
        aw_id_q       <= s_axi_awid;
        aw_addr_q     <= s_axi_awaddr;
        aw_len_q      <= s_axi_awlen;
        aw_size_q     <= s_axi_awsize;
        aw_burst_q    <= s_axi_awburst;
        wr_beats_left <= {1'b0, s_axi_awlen} + 9'd1;
        wr_meta_error <=
            ((s_axi_awburst != BURST_FIXED) &&
             (s_axi_awburst != BURST_INCR)) ||
            (s_axi_awsize > MAX_SIZE);
        wr_resp_accum <= RESP_OKAY;
      end

      if (s_axi_wvalid && s_axi_wready) begin
        w_full   <= 1'b1;
        w_data_q <= s_axi_wdata;
        w_strb_q <= s_axi_wstrb;
        w_last_q <= s_axi_wlast;
      end

      if (s_axi_arvalid && s_axi_arready) begin
        ar_full       <= 1'b1;
        ar_id_q       <= s_axi_arid;
        ar_addr_q     <= s_axi_araddr;
        ar_len_q      <= s_axi_arlen;
        ar_size_q     <= s_axi_arsize;
        ar_burst_q    <= s_axi_arburst;
        rd_beats_left <= {1'b0, s_axi_arlen} + 9'd1;
        rd_meta_error <=
            ((s_axi_arburst != BURST_FIXED) &&
             (s_axi_arburst != BURST_INCR)) ||
            (s_axi_arsize > MAX_SIZE);
      end

      if (link_req_valid && link_req_ready) begin
        link_req_valid <= 1'b0;
        inflight       <= 1'b1;
      end

      if (link_rsp_valid && link_rsp_ready) begin
        inflight <= 1'b0;

        if (inflight_write) begin
          if (inflight_last) begin
            aw_full <= 1'b0;
            if (inflight_protocol_error)
              w_full <= 1'b0;
            wr_beats_left <= '0;
            wr_meta_error <= 1'b0;
            wr_resp_accum <= RESP_OKAY;

            s_axi_bid <= aw_id_q;
            if (inflight_protocol_error || !link_rsp_write ||
                (link_rsp_id != aw_id_q))
              s_axi_bresp <= RESP_SLVERR;
            else if (wr_resp_accum != RESP_OKAY)
              s_axi_bresp <= wr_resp_accum;
            else
              s_axi_bresp <= link_rsp_resp;
            s_axi_bvalid <= 1'b1;
          end else begin
            wr_beats_left <= wr_beats_left - 9'd1;
            if (aw_burst_q == BURST_INCR)
              aw_addr_q <= incr_addr(aw_addr_q, aw_size_q);

            if (inflight_protocol_error || !link_rsp_write ||
                (link_rsp_id != aw_id_q))
              wr_resp_accum <= RESP_SLVERR;
            else if ((wr_resp_accum == RESP_OKAY) &&
                     (link_rsp_resp != RESP_OKAY))
              wr_resp_accum <= link_rsp_resp;
          end
        end else begin
          s_axi_rid   <= ar_id_q;
          s_axi_rdata <= link_rsp_rdata;
          if (link_rsp_write || (link_rsp_id != ar_id_q))
            s_axi_rresp <= RESP_SLVERR;
          else
            s_axi_rresp <= link_rsp_resp;
          s_axi_rlast  <= inflight_last;
          s_axi_rvalid <= 1'b1;
        end
      end

      if (!link_req_valid && !inflight && !s_axi_bvalid && !s_axi_rvalid) begin
        if (aw_full && w_full) begin
          if (wr_meta_error) begin
            w_full <= 1'b0;
            if (w_last_q || (wr_beats_left == 9'd1)) begin
              aw_full       <= 1'b0;
              wr_beats_left <= '0;
              wr_meta_error <= 1'b0;
              wr_resp_accum <= RESP_OKAY;
              s_axi_bid     <= aw_id_q;
              s_axi_bresp   <= RESP_SLVERR;
              s_axi_bvalid  <= 1'b1;
            end else begin
              wr_beats_left <= wr_beats_left - 9'd1;
            end
          end else begin
            link_req_valid          <= 1'b1;
            link_req_write          <= 1'b1;
            link_req_id             <= aw_id_q;
            link_req_addr           <= aw_addr_q;
            link_req_len            <= aw_len_q;
            link_req_size           <= aw_size_q;
            link_req_wdata          <= w_data_q;
            link_req_wstrb          <= w_strb_q;
            inflight_write          <= 1'b1;
            inflight_last           <= w_last_q || (wr_beats_left == 9'd1);
            inflight_protocol_error <=
                (w_last_q != (wr_beats_left == 9'd1));
            w_full <= 1'b0;
          end
        end else if (ar_full) begin
          if (rd_meta_error) begin
            ar_full       <= 1'b0;
            rd_beats_left <= '0;
            rd_meta_error <= 1'b0;
            s_axi_rid     <= ar_id_q;
            s_axi_rdata   <= '0;
            s_axi_rresp   <= RESP_SLVERR;
            s_axi_rlast   <= 1'b1;
            s_axi_rvalid  <= 1'b1;
          end else begin
            link_req_valid          <= 1'b1;
            link_req_write          <= 1'b0;
            link_req_id             <= ar_id_q;
            link_req_addr           <= ar_addr_q;
            link_req_len            <= ar_len_q;
            link_req_size           <= ar_size_q;
            link_req_wdata          <= '0;
            link_req_wstrb          <= '0;
            inflight_write          <= 1'b0;
            inflight_last           <= (rd_beats_left == 9'd1);
            inflight_protocol_error <= 1'b0;
          end
        end
      end
    end
  end

endmodule
