module top;
  import uvm_pkg::*;
  import axi_ucie_pkg::*;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic stall_enable = 1'b1;

  always #5 clk = ~clk;

  axi_if axi (
    .aclk(clk),
    .aresetn(rst_n)
  );

  ucie_link_if link (
    .clk(clk),
    .rst_n(rst_n)
  );

  axi_ucie_bridge dut (
    .aclk(clk),
    .aresetn(rst_n),
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
    .ucie_tx_valid(link.tx_valid),
    .ucie_tx_ready(link.tx_ready),
    .ucie_tx_data(link.tx_data),
    .ucie_rx_valid(link.rx_valid),
    .ucie_rx_ready(link.rx_ready),
    .ucie_rx_data(link.rx_data)
  );

  ucie_responder_model responder (
    .clk(clk),
    .rst_n(rst_n),
    .stall_enable(stall_enable),
    .req_valid(link.tx_valid),
    .req_ready(link.tx_ready),
    .req_data(link.tx_data),
    .rsp_valid(link.rx_valid),
    .rsp_ready(link.rx_ready),
    .rsp_data(link.rx_data)
  );

  axi_protocol_sva checks (
    .axi(axi),
    .link(link)
  );

  initial begin
    repeat (5) @(posedge clk);
    rst_n <= 1'b1;
  end

  initial begin
    uvm_config_db#(virtual axi_if)::set(null, "*", "vif", axi);
    uvm_config_db#(virtual ucie_link_if)::set(null, "*", "ucie_vif", link);
    run_test();
  end

endmodule
