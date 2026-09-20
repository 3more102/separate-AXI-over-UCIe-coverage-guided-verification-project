module rv_slice #(
  parameter int W = 1
) (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         stall,
  input  logic [W-1:0] s_payload,
  input  logic         s_valid,
  output logic         s_ready,
  output logic [W-1:0] m_payload,
  output logic         m_valid,
  input  logic         m_ready
);
  logic         full;
  logic [W-1:0] payload_q;

  assign m_payload = payload_q;
  assign m_valid   = full && !stall;
  assign s_ready   = !full || (m_ready && m_valid);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      full      <= 1'b0;
      payload_q <= '0;
    end else begin
      if (m_valid && m_ready)
        full <= 1'b0;

      if (s_valid && s_ready) begin
        payload_q <= s_payload;
        full      <= 1'b1;
      end
    end
  end
endmodule

module axi_ucie_reference_dut #(
  parameter int ID_W   = 4,
  parameter int ADDR_W = 32,
  parameter int DATA_W = 32
) (
  input logic clk,
  input logic rst_n,
  input logic req_stall,
  input logic rsp_stall,
  axi_if.slave  s_axi,
  axi_if.master m_axi
);
  localparam int STRB_W = DATA_W/8;
  localparam int AW_W = ID_W + ADDR_W + 8 + 3 + 2;
  localparam int W_W  = DATA_W + STRB_W + 1;
  localparam int B_W  = ID_W + 2;
  localparam int AR_W = AW_W;
  localparam int R_W  = ID_W + DATA_W + 2 + 1;

  logic [AW_W-1:0] aw_in, aw_out;
  logic [W_W-1:0]  w_in,  w_out;
  logic [B_W-1:0]  b_in,  b_out;
  logic [AR_W-1:0] ar_in, ar_out;
  logic [R_W-1:0]  r_in,  r_out;

  assign aw_in = {s_axi.awid, s_axi.awaddr, s_axi.awlen, s_axi.awsize, s_axi.awburst};
  assign {m_axi.awid, m_axi.awaddr, m_axi.awlen, m_axi.awsize, m_axi.awburst} = aw_out;

  assign w_in = {s_axi.wdata, s_axi.wstrb, s_axi.wlast};
  assign {m_axi.wdata, m_axi.wstrb, m_axi.wlast} = w_out;

  assign ar_in = {s_axi.arid, s_axi.araddr, s_axi.arlen, s_axi.arsize, s_axi.arburst};
  assign {m_axi.arid, m_axi.araddr, m_axi.arlen, m_axi.arsize, m_axi.arburst} = ar_out;

  assign b_in = {m_axi.bid, m_axi.bresp};
  assign {s_axi.bid, s_axi.bresp} = b_out;

  assign r_in = {m_axi.rid, m_axi.rdata, m_axi.rresp, m_axi.rlast};
  assign {s_axi.rid, s_axi.rdata, s_axi.rresp, s_axi.rlast} = r_out;

  rv_slice #(.W(AW_W)) u_aw (
    .clk(clk), .rst_n(rst_n), .stall(req_stall),
    .s_payload(aw_in), .s_valid(s_axi.awvalid), .s_ready(s_axi.awready),
    .m_payload(aw_out), .m_valid(m_axi.awvalid), .m_ready(m_axi.awready)
  );

  rv_slice #(.W(W_W)) u_w (
    .clk(clk), .rst_n(rst_n), .stall(req_stall),
    .s_payload(w_in), .s_valid(s_axi.wvalid), .s_ready(s_axi.wready),
    .m_payload(w_out), .m_valid(m_axi.wvalid), .m_ready(m_axi.wready)
  );

  rv_slice #(.W(AR_W)) u_ar (
    .clk(clk), .rst_n(rst_n), .stall(req_stall),
    .s_payload(ar_in), .s_valid(s_axi.arvalid), .s_ready(s_axi.arready),
    .m_payload(ar_out), .m_valid(m_axi.arvalid), .m_ready(m_axi.arready)
  );

  rv_slice #(.W(B_W)) u_b (
    .clk(clk), .rst_n(rst_n), .stall(rsp_stall),
    .s_payload(b_in), .s_valid(m_axi.bvalid), .s_ready(m_axi.bready),
    .m_payload(b_out), .m_valid(s_axi.bvalid), .m_ready(s_axi.bready)
  );

  rv_slice #(.W(R_W)) u_r (
    .clk(clk), .rst_n(rst_n), .stall(rsp_stall),
    .s_payload(r_in), .s_valid(m_axi.rvalid), .s_ready(m_axi.rready),
    .m_payload(r_out), .m_valid(s_axi.rvalid), .m_ready(s_axi.rready)
  );
endmodule
