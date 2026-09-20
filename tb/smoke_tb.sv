module smoke_tb;
  localparam int ID_W   = 4;
  localparam int ADDR_W = 32;
  localparam int DATA_W = 32;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic req_stall = 1'b0;
  logic rsp_stall = 1'b0;
  logic [7:0] lfsr = 8'hA5;

  axi_if #(.ID_W(ID_W), .ADDR_W(ADDR_W), .DATA_W(DATA_W)) src_if(clk, rst_n);
  axi_if #(.ID_W(ID_W), .ADDR_W(ADDR_W), .DATA_W(DATA_W)) dst_if(clk, rst_n);

  axi_ucie_reference_dut #(.ID_W(ID_W), .ADDR_W(ADDR_W), .DATA_W(DATA_W)) dut (
    .clk(clk), .rst_n(rst_n), .req_stall(req_stall), .rsp_stall(rsp_stall),
    .s_axi(src_if), .m_axi(dst_if)
  );

  axi_memory_slave #(.ID_W(ID_W), .ADDR_W(ADDR_W), .DATA_W(DATA_W)) mem (
    .clk(clk), .rst_n(rst_n), .axi(dst_if)
  );

  always #5 clk = ~clk;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lfsr      <= 8'hA5;
      req_stall <= 1'b0;
      rsp_stall <= 1'b0;
    end else begin
      lfsr      <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
      req_stall <= lfsr[0] & lfsr[3];
      rsp_stall <= lfsr[1] & lfsr[4];
    end
  end

  task automatic write_burst(input logic [ADDR_W-1:0] addr, input int beats);
    int i;
    begin
      @(posedge clk);
      src_if.awid    <= 4'h3;
      src_if.awaddr  <= addr;
      src_if.awlen   <= beats-1;
      src_if.awsize  <= 3'd2;
      src_if.awburst <= 2'b01;
      src_if.awvalid <= 1'b1;
      do @(posedge clk); while (!src_if.awready);
      src_if.awvalid <= 1'b0;

      for (i = 0; i < beats; i++) begin
        src_if.wdata  <= 32'hA500_0000 + i;
        src_if.wstrb  <= '1;
        src_if.wlast  <= (i == beats-1);
        src_if.wvalid <= 1'b1;
        do @(posedge clk); while (!src_if.wready);
        src_if.wvalid <= 1'b0;
      end

      src_if.bready <= 1'b1;
      do @(posedge clk); while (!src_if.bvalid);
      if (src_if.bresp != 2'b00)
        $fatal(1, "Write response error: %0b", src_if.bresp);
      if (src_if.bid != 4'h3)
        $fatal(1, "Write ID mismatch");
      @(posedge clk);
      src_if.bready <= 1'b0;
    end
  endtask

  task automatic read_and_check(input logic [ADDR_W-1:0] addr, input int beats);
    int i;
    logic [31:0] expected;
    begin
      @(posedge clk);
      src_if.arid    <= 4'h7;
      src_if.araddr  <= addr;
      src_if.arlen   <= beats-1;
      src_if.arsize  <= 3'd2;
      src_if.arburst <= 2'b01;
      src_if.arvalid <= 1'b1;
      do @(posedge clk); while (!src_if.arready);
      src_if.arvalid <= 1'b0;

      src_if.rready <= 1'b1;
      for (i = 0; i < beats; i++) begin
        do @(posedge clk); while (!src_if.rvalid);
        expected = 32'hA500_0000 + i;
        if (src_if.rdata !== expected)
          $fatal(1, "Read mismatch beat=%0d got=%08x expected=%08x", i, src_if.rdata, expected);
        if (src_if.rresp != 2'b00)
          $fatal(1, "Read response error");
        if (src_if.rid != 4'h7)
          $fatal(1, "Read ID mismatch");
        if (src_if.rlast !== (i == beats-1))
          $fatal(1, "RLAST mismatch beat=%0d", i);
      end
      @(posedge clk);
      src_if.rready <= 1'b0;
    end
  endtask

  initial begin
    src_if.awid = '0; src_if.awaddr = '0; src_if.awlen = '0; src_if.awsize = '0;
    src_if.awburst = '0; src_if.awvalid = 1'b0;
    src_if.wdata = '0; src_if.wstrb = '0; src_if.wlast = 1'b0; src_if.wvalid = 1'b0;
    src_if.bready = 1'b0;
    src_if.arid = '0; src_if.araddr = '0; src_if.arlen = '0; src_if.arsize = '0;
    src_if.arburst = '0; src_if.arvalid = 1'b0;
    src_if.rready = 1'b0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    write_burst(32'h0000_0100, 4);
    read_and_check(32'h0000_0100, 4);

    $display("SMOKE PASS: 4-beat AXI burst preserved across stalled transport");
    repeat (3) @(posedge clk);
    $finish;
  end

  initial begin
    #20000;
    $fatal(1, "Smoke timeout");
  end
endmodule
