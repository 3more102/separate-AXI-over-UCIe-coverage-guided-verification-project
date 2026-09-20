module ucie_mem_endpoint #(
  parameter int ADDR_W = 32,
  parameter int DATA_W = 64,
  parameter int ID_W   = 4,
  parameter int DEPTH  = 256
) (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  allow_req,

  // Verification-only response injection. When asserted for an accepted
  // request, return inject_resp and suppress write-side memory updates.
  input  logic                  inject_error,
  input  logic [1:0]            inject_resp,

  input  logic                  req_valid,
  output logic                  req_ready,
  input  logic                  req_write,
  input  logic [ID_W-1:0]       req_id,
  input  logic [ADDR_W-1:0]     req_addr,
  input  logic [7:0]            req_len,
  input  logic [2:0]            req_size,
  input  logic [DATA_W-1:0]     req_wdata,
  input  logic [DATA_W/8-1:0]   req_wstrb,

  output logic                  rsp_valid,
  input  logic                  rsp_ready,
  output logic                  rsp_write,
  output logic [ID_W-1:0]       rsp_id,
  output logic [1:0]            rsp_resp,
  output logic [DATA_W-1:0]     rsp_rdata
);

  localparam int BYTE_LANES = DATA_W / 8;
  localparam int ADDR_LSB   = $clog2(BYTE_LANES);
  localparam int INDEX_W    = $clog2(DEPTH);

  logic [DATA_W-1:0] mem [0:DEPTH-1];
  wire [INDEX_W-1:0] req_index = req_addr[ADDR_LSB +: INDEX_W];

  integer lane;

  assign req_ready = rst_n && allow_req && !rsp_valid;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rsp_valid <= 1'b0;
      rsp_write <= 1'b0;
      rsp_id    <= '0;
      rsp_resp  <= 2'b00;
      rsp_rdata <= '0;
    end else begin
      if (rsp_valid && rsp_ready)
        rsp_valid <= 1'b0;

      if (req_valid && req_ready) begin
        rsp_valid <= 1'b1;
        rsp_write <= req_write;
        rsp_id    <= req_id;
        rsp_resp  <= inject_error ? inject_resp : 2'b00;

        if (req_write) begin
          if (!inject_error) begin
            for (lane = 0; lane < BYTE_LANES; lane = lane + 1)
              if (req_wstrb[lane])
                mem[req_index][8*lane +: 8] <= req_wdata[8*lane +: 8];
          end
          rsp_rdata <= '0;
        end else begin
          rsp_rdata <= inject_error ? '0 : mem[req_index];
        end
      end
    end
  end

  logic _unused;
  always_comb _unused = ^{req_len, req_size};

endmodule
