`timescale 1ns/1ps

module narrow_lane_smoke_tb;
  localparam int ID_W   = 4;
  localparam int ADDR_W = 32;
  localparam int DATA_W = 32;

  logic clk = 1'b0;
  logic rst_n = 1'b0;

  always #5 clk = ~clk;

  axi_if #(
    .ID_W(ID_W), .ADDR_W(ADDR_W), .DATA_W(DATA_W)
  ) src_if(clk, rst_n);

  axi_if #(
    .ID_W(ID_W), .ADDR_W(ADDR_W), .DATA_W(DATA_W)
  ) dst_if(clk, rst_n);

  axi_ucie_reference_dut #(
    .ID_W(ID_W), .ADDR_W(ADDR_W), .DATA_W(DATA_W)
  ) dut (
    .clk(clk), .rst_n(rst_n),
    .req_stall(1'b0), .rsp_stall(1'b0),
    .s_axi(src_if), .m_axi(dst_if)
  );

  axi_memory_slave #(
    .ID_W(ID_W), .ADDR_W(ADDR_W), .DATA_W(DATA_W), .MEM_BYTES(4096)
  ) mem (
    .clk(clk), .rst_n(rst_n), .axi(dst_if)
  );

  task automatic axi_write_single(
    input logic [ADDR_W-1:0] addr,
    input logic [2:0] size,
    input logic [DATA_W/8-1:0] strb,
    input logic [DATA_W-1:0] data,
    input logic [ID_W-1:0] id
  );
    begin
      @(negedge clk);
      src_if.awid    = id;
      src_if.awaddr  = addr;
      src_if.awlen   = 8'd0;
      src_if.awsize  = size;
      src_if.awburst = 2'b01;
      src_if.awvalid = 1'b1;

      do @(posedge clk); while (!src_if.awready);
      @(negedge clk);
      src_if.awvalid = 1'b0;

      src_if.wdata  = data;
      src_if.wstrb  = strb;
      src_if.wlast  = 1'b1;
      src_if.wvalid = 1'b1;

      do @(posedge clk); while (!src_if.wready);
      @(negedge clk);
      src_if.wvalid = 1'b0;

      src_if.bready = 1'b1;
      do @(posedge clk); while (!src_if.bvalid);

      if (src_if.bid !== id)
        $fatal(1, "BID mismatch exp=%0h got=%0h", id, src_if.bid);
      if (src_if.bresp !== 2'b00)
        $fatal(1, "BRESP not OKAY: %0b", src_if.bresp);

      @(negedge clk);
      src_if.bready = 1'b0;
    end
  endtask

  task automatic axi_read_single_expect(
    input logic [ADDR_W-1:0] addr,
    input logic [2:0] size,
    input logic [DATA_W-1:0] mask,
    input logic [DATA_W-1:0] expected,
    input logic [ID_W-1:0] id
  );
    begin
      @(negedge clk);
      src_if.arid    = id;
      src_if.araddr  = addr;
      src_if.arlen   = 8'd0;
      src_if.arsize  = size;
      src_if.arburst = 2'b01;
      src_if.arvalid = 1'b1;

      do @(posedge clk); while (!src_if.arready);
      @(negedge clk);
      src_if.arvalid = 1'b0;
      src_if.rready  = 1'b1;

      do @(posedge clk); while (!src_if.rvalid);

      if (src_if.rid !== id)
        $fatal(1, "RID mismatch exp=%0h got=%0h", id, src_if.rid);
      if (src_if.rresp !== 2'b00)
        $fatal(1, "RRESP not OKAY: %0b", src_if.rresp);
      if (src_if.rlast !== 1'b1)
        $fatal(1, "Single-beat read did not assert RLAST");
      if ((src_if.rdata & mask) !== (expected & mask))
        $fatal(
          1,
          "RDATA mismatch addr=%08h mask=%08h got=%08h expected=%08h",
          addr, mask, src_if.rdata, expected
        );

      @(negedge clk);
      src_if.rready = 1'b0;
    end
  endtask

  initial begin
    src_if.awid = '0;
    src_if.awaddr = '0;
    src_if.awlen = '0;
    src_if.awsize = '0;
    src_if.awburst = '0;
    src_if.awvalid = 1'b0;
    src_if.wdata = '0;
    src_if.wstrb = '0;
    src_if.wlast = 1'b0;
    src_if.wvalid = 1'b0;
    src_if.bready = 1'b0;
    src_if.arid = '0;
    src_if.araddr = '0;
    src_if.arlen = '0;
    src_if.arsize = '0;
    src_if.arburst = '0;
    src_if.arvalid = 1'b0;
    src_if.rready = 1'b0;

    repeat (5) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;

    // Initialize one aligned bus word.
    axi_write_single(
      32'h0000_0040, 3'd2, 4'b1111, 32'h1122_3344, 4'h1
    );

    // A halfword read at address +2 must return bytes 2..3 in lanes 2..3.
    // This independently checks read-data lane alignment.
    axi_read_single_expect(
      32'h0000_0042, 3'd1, 32'hFFFF_0000, 32'h1122_0000, 4'h2
    );

    // A halfword write at address +2 must update bytes 2..3 of the aligned word.
    axi_write_single(
      32'h0000_0042, 3'd1, 4'b1100, 32'hAABB_0000, 4'h3
    );
    axi_read_single_expect(
      32'h0000_0040, 3'd2, 32'hFFFF_FFFF, 32'hAABB_3344, 4'h4
    );

    // A byte write at address +1 must update lane 1, not addr+lane.
    axi_write_single(
      32'h0000_0041, 3'd0, 4'b0010, 32'h0000_CC00, 4'h5
    );
    axi_read_single_expect(
      32'h0000_0040, 3'd2, 32'hFFFF_FFFF, 32'hAABB_CC44, 4'h6
    );

    $display("NARROW LANE SMOKE PASS");
    $finish;
  end

  initial begin
    #100us;
    $fatal(1, "NARROW LANE SMOKE TIMEOUT");
  end
endmodule
