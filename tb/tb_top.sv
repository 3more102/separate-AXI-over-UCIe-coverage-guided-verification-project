module tb_top;
  import uvm_pkg::*;
  import axi_ucie_tb_pkg::*;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic req_stall = 1'b0;
  logic rsp_stall = 1'b0;
  logic [15:0] lfsr = 16'hACE1;
  bit no_stall;

  axi_if #(
    .ID_W(AXI_ID_W), .ADDR_W(AXI_ADDR_W), .DATA_W(AXI_DATA_W)
  ) src_if(clk, rst_n);

  axi_if #(
    .ID_W(AXI_ID_W), .ADDR_W(AXI_ADDR_W), .DATA_W(AXI_DATA_W)
  ) dst_if(clk, rst_n);

  axi_ucie_reference_dut #(
    .ID_W(AXI_ID_W), .ADDR_W(AXI_ADDR_W), .DATA_W(AXI_DATA_W)
  ) dut (
    .clk(clk), .rst_n(rst_n),
    .req_stall(req_stall), .rsp_stall(rsp_stall),
    .s_axi(src_if), .m_axi(dst_if)
  );

  axi_memory_slave #(
    .ID_W(AXI_ID_W), .ADDR_W(AXI_ADDR_W), .DATA_W(AXI_DATA_W)
  ) mem (
    .clk(clk), .rst_n(rst_n), .axi(dst_if)
  );

  axi_protocol_sva src_sva(.axi(src_if));
  axi_protocol_sva dst_sva(.axi(dst_if));

  always #5 clk = ~clk;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lfsr      <= 16'hACE1;
      req_stall <= 1'b0;
      rsp_stall <= 1'b0;
    end else begin
      lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      if (no_stall) begin
        req_stall <= 1'b0;
        rsp_stall <= 1'b0;
      end else begin
        req_stall <= lfsr[0] & lfsr[4];
        rsp_stall <= lfsr[1] & lfsr[5];
      end
    end
  end

  initial begin
    no_stall = $test$plusargs("NO_STALL");
    uvm_config_db#(axi_vif_t)::set(null, "*", "src_vif", src_if);
    uvm_config_db#(axi_vif_t)::set(null, "*", "dst_vif", dst_if);

    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    run_test();
  end

  initial begin
    #2ms;
    \`uvm_fatal("TIMEOUT", "Global simulation timeout")
  end
endmodule
