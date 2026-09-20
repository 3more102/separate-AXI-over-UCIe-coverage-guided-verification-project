module link_protocol_checker #(
  parameter int ADDR_W = 32,
  parameter int DATA_W = 64,
  parameter int ID_W   = 4
) (
  input  logic                  clk,
  input  logic                  rst_n,

  input  logic                  req_valid,
  input  logic                  req_ready,
  input  logic                  req_write,
  input  logic [ID_W-1:0]       req_id,
  input  logic [ADDR_W-1:0]     req_addr,
  input  logic [7:0]            req_len,
  input  logic [2:0]            req_size,
  input  logic [DATA_W-1:0]     req_wdata,
  input  logic [DATA_W/8-1:0]   req_wstrb,

  input  logic                  rsp_valid,
  input  logic                  rsp_ready,
  input  logic                  rsp_write,
  input  logic [ID_W-1:0]       rsp_id,
  input  logic [1:0]            rsp_resp,
  input  logic [DATA_W-1:0]     rsp_rdata,

  output logic                  error_seen
);

  logic prev_req_stalled;
  logic prev_rsp_stalled;

  logic                prev_req_write;
  logic [ID_W-1:0]     prev_req_id;
  logic [ADDR_W-1:0]   prev_req_addr;
  logic [7:0]          prev_req_len;
  logic [2:0]          prev_req_size;
  logic [DATA_W-1:0]   prev_req_wdata;
  logic [DATA_W/8-1:0] prev_req_wstrb;

  logic                prev_rsp_write;
  logic [ID_W-1:0]     prev_rsp_id;
  logic [1:0]          prev_rsp_resp;
  logic [DATA_W-1:0]   prev_rsp_rdata;

  logic                outstanding;
  logic                expected_write;
  logic [ID_W-1:0]     expected_id;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      error_seen       <= 1'b0;
      prev_req_stalled <= 1'b0;
      prev_rsp_stalled <= 1'b0;
      prev_req_write   <= 1'b0;
      prev_req_id      <= '0;
      prev_req_addr    <= '0;
      prev_req_len     <= '0;
      prev_req_size    <= '0;
      prev_req_wdata   <= '0;
      prev_req_wstrb   <= '0;
      prev_rsp_write   <= 1'b0;
      prev_rsp_id      <= '0;
      prev_rsp_resp    <= '0;
      prev_rsp_rdata   <= '0;
      outstanding      <= 1'b0;
      expected_write   <= 1'b0;
      expected_id      <= '0;
    end else begin
      if (prev_req_stalled) begin
        if (!req_valid) begin
          error_seen <= 1'b1;
          $display("LINK_CHECKER_ERROR: request VALID dropped before READY");
        end else if ({req_write, req_id, req_addr, req_len, req_size,
                      req_wdata, req_wstrb} !==
                     {prev_req_write, prev_req_id, prev_req_addr, prev_req_len,
                      prev_req_size, prev_req_wdata, prev_req_wstrb}) begin
          error_seen <= 1'b1;
          $display("LINK_CHECKER_ERROR: request payload changed while stalled");
        end
      end

      if (prev_rsp_stalled) begin
        if (!rsp_valid) begin
          error_seen <= 1'b1;
          $display("LINK_CHECKER_ERROR: response VALID dropped before READY");
        end else if ({rsp_write, rsp_id, rsp_resp, rsp_rdata} !==
                     {prev_rsp_write, prev_rsp_id, prev_rsp_resp,
                      prev_rsp_rdata}) begin
          error_seen <= 1'b1;
          $display("LINK_CHECKER_ERROR: response payload changed while stalled");
        end
      end

      if (rsp_valid) begin
        if (!outstanding) begin
          error_seen <= 1'b1;
          $display("LINK_CHECKER_ERROR: response observed with no outstanding request");
        end else begin
          if (rsp_write !== expected_write) begin
            error_seen <= 1'b1;
            $display("LINK_CHECKER_ERROR: response direction does not match request");
          end
          if (rsp_id !== expected_id) begin
            error_seen <= 1'b1;
            $display("LINK_CHECKER_ERROR: response ID does not match request");
          end
        end
      end

      if (req_valid && req_ready) begin
        if (outstanding) begin
          error_seen <= 1'b1;
          $display("LINK_CHECKER_ERROR: second request accepted while one is outstanding");
        end
        outstanding    <= 1'b1;
        expected_write <= req_write;
        expected_id    <= req_id;
      end

      if (rsp_valid && rsp_ready) begin
        if (!outstanding) begin
          error_seen <= 1'b1;
          $display("LINK_CHECKER_ERROR: response handshake without outstanding request");
        end
        outstanding <= 1'b0;
      end

      prev_req_stalled <= req_valid && !req_ready;
      prev_rsp_stalled <= rsp_valid && !rsp_ready;

      if (req_valid) begin
        prev_req_write <= req_write;
        prev_req_id    <= req_id;
        prev_req_addr  <= req_addr;
        prev_req_len   <= req_len;
        prev_req_size  <= req_size;
        prev_req_wdata <= req_wdata;
        prev_req_wstrb <= req_wstrb;
      end

      if (rsp_valid) begin
        prev_rsp_write <= rsp_write;
        prev_rsp_id    <= rsp_id;
        prev_rsp_resp  <= rsp_resp;
        prev_rsp_rdata <= rsp_rdata;
      end
    end
  end

endmodule
