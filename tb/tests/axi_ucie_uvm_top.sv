`timescale 1ns/1ps

module axi_ucie_uvm_top;
  import uvm_pkg::*;
  import axi_ucie_uvm_pkg::*;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic allow_req = 1'b1;

  always #5 clk = ~clk;

  axi_if #(
    .ID_W(AXI_ID_W),
    .ADDR_W(AXI_ADDR_W),
    .DATA_W(AXI_DATA_W)
  ) axi (
    .aclk(clk),
    .aresetn(rst_n)
  );

  logic req_valid;
  logic req_ready;
  logic req_write;
  logic [AXI_ID_W-1:0] req_id;
  logic [AXI_ADDR_W-1:0] req_addr;
  logic [7:0] req_len;
  logic [2:0] req_size;
  logic [AXI_DATA_W-1:0] req_wdata;
  logic [AXI_DATA_W/8-1:0] req_wstrb;

  logic rsp_valid;
  logic rsp_ready;
  logic rsp_write;
  logic [AXI_ID_W-1:0] rsp_id;
  logic [1:0] rsp_resp;
  logic [AXI_DATA_W-1:0] rsp_rdata;

  axi_ucie_bridge #(
    .ADDR_W(AXI_ADDR_W),
    .DATA_W(AXI_DATA_W),
    .ID_W(AXI_ID_W)
  ) dut (
    .clk,
    .rst_n,
    .s_axi_awid(axi.awid),
    .s_axi_awaddr(axi.awaddr),
    .s_axi_awlen(axi.awlen),
    .s_axi_awsize(axi.awsize),
    .s_axi_awburst(axi.awburst),
    .s_axi_awvalid(axi.awvalid),
    .s_axi_awready(axi.awready),
    .s_axi_wdata(axi.wdata),
    .s_axi_wstrb(axi.wstrb),
    .s_axi_wlast(axi.wlast),
    .s_axi_wvalid(axi.wvalid),
    .s_axi_wready(axi.wready),
    .s_axi_bid(axi.bid),
    .s_axi_bresp(axi.bresp),
    .s_axi_bvalid(axi.bvalid),
    .s_axi_bready(axi.bready),
    .s_axi_arid(axi.arid),
    .s_axi_araddr(axi.araddr),
    .s_axi_arlen(axi.arlen),
    .s_axi_arsize(axi.arsize),
    .s_axi_arburst(axi.arburst),
    .s_axi_arvalid(axi.arvalid),
    .s_axi_arready(axi.arready),
    .s_axi_rid(axi.rid),
    .s_axi_rdata(axi.rdata),
    .s_axi_rresp(axi.rresp),
    .s_axi_rlast(axi.rlast),
    .s_axi_rvalid(axi.rvalid),
    .s_axi_rready(axi.rready),
    .link_req_valid(req_valid),
    .link_req_ready(req_ready),
    .link_req_write(req_write),
    .link_req_id(req_id),
    .link_req_addr(req_addr),
    .link_req_len(req_len),
    .link_req_size(req_size),
    .link_req_wdata(req_wdata),
    .link_req_wstrb(req_wstrb),
    .link_rsp_valid(rsp_valid),
    .link_rsp_ready(rsp_ready),
    .link_rsp_write(rsp_write),
    .link_rsp_id(rsp_id),
    .link_rsp_resp(rsp_resp),
    .link_rsp_rdata(rsp_rdata)
  );

  ucie_mem_endpoint #(
    .ADDR_W(AXI_ADDR_W),
    .DATA_W(AXI_DATA_W),
    .ID_W(AXI_ID_W),
    .DEPTH(256)
  ) endpoint (
    .clk,
    .rst_n,
    .allow_req,
    .req_valid,
    .req_ready,
    .req_write,
    .req_id,
    .req_addr,
    .req_len,
    .req_size,
    .req_wdata,
    .req_wstrb,
    .rsp_valid,
    .rsp_ready,
    .rsp_write,
    .rsp_id,
    .rsp_resp,
    .rsp_rdata
  );

  initial begin
    repeat (5) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
  end

  initial begin
    uvm_config_db#(axi_vif_t)::set(null, "uvm_test_top.env.agent*", "vif", axi);
    run_test("axi_ucie_smoke_test");
  end

endmodule
