`timescale 1ns/1ps

module reference_smoke_tb;
  localparam int ID_W   = 4;
  localparam int ADDR_W = 32;
  localparam int DATA_W = 32;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic req_stall = 1'b0;
  logic rsp_stall = 1'b0;
  logic [7:0] lfsr = 8'hA5;
  integer errors = 0;

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
    .req_stall(req_stall), .rsp_stall(rsp_stall),
    .s_axi(src_if), .m_axi(dst_if)
  );

  axi_memory_slave #(
    .ID_W(ID_W), .ADDR_W(ADDR_W), .DATA_W(DATA_W), .MEM_BYTES(4096)
  ) mem (
    .clk(clk), .rst_n(rst_n), .axi(dst_if)
  );

  task automatic fail(input string msg);
    begin
      errors = errors + 1;
      $display("ERROR: %s", msg);
    end
  endtask

  function automatic logic [DATA_W-1:0] select_word(
    input int index,
    input logic [DATA_W-1:0] d0,
    input logic [DATA_W-1:0] d1,
    input logic [DATA_W-1:0] d2,
    input logic [DATA_W-1:0] d3
  );
    case (index)
      0: select_word = d0;
      1: select_word = d1;
      2: select_word = d2;
      default: select_word = d3;
    endcase
  endfunction

  task automatic axi_write4(
    input logic [ADDR_W-1:0] addr,
    input logic [1:0] burst,
    input logic [ID_W-1:0] id,
    input logic [DATA_W-1:0] d0,
    input logic [DATA_W-1:0] d1,
    input logic [DATA_W-1:0] d2,
    input logic [DATA_W-1:0] d3
  );
    logic [DATA_W-1:0] beat_data;
    begin
      @(negedge clk);
      src_if.awid    = id;
      src_if.awaddr  = addr;
      src_if.awlen   = 8'd3;
      src_if.awsize  = 3'd2;
      src_if.awburst = burst;
      src_if.awvalid = 1'b1;

      do @(posedge clk); while (!src_if.awready);
      @(negedge clk);
      src_if.awvalid = 1'b0;

      for (int beat = 0; beat < 4; beat++) begin
        beat_data = select_word(beat, d0, d1, d2, d3);
        src_if.wdata  = beat_data;
        src_if.wstrb  = '1;
        src_if.wlast  = (beat == 3);
        src_if.wvalid = 1'b1;

        do @(posedge clk); while (!src_if.wready);
        @(negedge clk);
        src_if.wvalid = 1'b0;
      end

      src_if.bready = 1'b1;
      do @(posedge clk); while (!src_if.bvalid);
      if (src_if.bid !== id)
        fail($sformatf("BID mismatch exp=%0h got=%0h", id, src_if.bid));
      if (src_if.bresp !== 2'b00)
        fail($sformatf("BRESP not OKAY: %0b", src_if.bresp));
      @(negedge clk);
      src_if.bready = 1'b0;
    end
  endtask

  task automatic axi_read4_expect(
    input logic [ADDR_W-1:0] addr,
    input logic [1:0] burst,
    input logic [ID_W-1:0] id,
    input logic [DATA_W-1:0] e0,
    input logic [DATA_W-1:0] e1,
    input logic [DATA_W-1:0] e2,
    input logic [DATA_W-1:0] e3
  );
    logic [DATA_W-1:0] expected;
    begin
      @(negedge clk);
      src_if.arid    = id;
      src_if.araddr  = addr;
      src_if.arlen   = 8'd3;
      src_if.arsize  = 3'd2;
      src_if.arburst = burst;
      src_if.arvalid = 1'b1;

      do @(posedge clk); while (!src_if.arready);
      @(negedge clk);
      src_if.arvalid = 1'b0;
      src_if.rready  = 1'b1;

      for (int beat = 0; beat < 4; beat++) begin
        do @(posedge clk); while (!src_if.rvalid);
        expected = select_word(beat, e0, e1, e2, e3);
        if (src_if.rid !== id)
          fail($sformatf("RID mismatch beat=%0d exp=%0h got=%0h",
                         beat, id, src_if.rid));
        if (src_if.rresp !== 2'b00)
          fail($sformatf("RRESP not OKAY beat=%0d resp=%0b",
                         beat, src_if.rresp));
        if (src_if.rdata !== expected)
          fail($sformatf("RDATA mismatch beat=%0d exp=%h got=%h",
                         beat, expected, src_if.rdata));
        if (src_if.rlast !== (beat == 3))
          fail($sformatf("RLAST mismatch beat=%0d value=%0b",
                         beat, src_if.rlast));
        @(negedge clk);
      end
      src_if.rready = 1'b0;
    end
  endtask

  task automatic axi_write1(
    input logic [ADDR_W-1:0] addr,
    input logic [2:0] size,
    input logic [DATA_W-1:0] data,
    input logic [DATA_W/8-1:0] strb,
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
        fail($sformatf("narrow BID mismatch exp=%0h got=%0h", id, src_if.bid));
      if (src_if.bresp !== 2'b00)
        fail($sformatf("narrow BRESP not OKAY: %0b", src_if.bresp));
      @(negedge clk);
      src_if.bready = 1'b0;
    end
  endtask

  task automatic axi_read1_expect_masked(
    input logic [ADDR_W-1:0] addr,
    input logic [2:0] size,
    input logic [ID_W-1:0] id,
    input logic [DATA_W-1:0] expected,
    input logic [DATA_W-1:0] mask
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
        fail($sformatf("narrow RID mismatch exp=%0h got=%0h", id, src_if.rid));
      if (src_if.rresp !== 2'b00)
        fail($sformatf("narrow RRESP not OKAY: %0b", src_if.rresp));
      if ((src_if.rdata & mask) !== (expected & mask))
        fail($sformatf("narrow RDATA mismatch addr=%h exp=%h got=%h mask=%h",
                       addr, expected, src_if.rdata, mask));
      if (!src_if.rlast)
        fail("narrow single-beat read did not assert RLAST");
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

    $display("TEST: four-beat INCR burst survives deterministic request/response stalls");
    axi_write4(
      32'h0000_0040, 2'b01, 4'h3,
      32'h1111_0001, 32'h2222_0002, 32'h3333_0003, 32'h4444_0004
    );
    axi_read4_expect(
      32'h0000_0040, 2'b01, 4'h4,
      32'h1111_0001, 32'h2222_0002, 32'h3333_0003, 32'h4444_0004
    );

    $display("TEST: four-beat FIXED burst holds one address under transport stalls");
    axi_write4(
      32'h0000_0080, 2'b00, 4'h5,
      32'hAAAA_0001, 32'hBBBB_0002, 32'hCCCC_0003, 32'hDDDD_0004
    );
    axi_read4_expect(
      32'h0000_0080, 2'b00, 4'h6,
      32'hDDDD_0004, 32'hDDDD_0004, 32'hDDDD_0004, 32'hDDDD_0004
    );

    $display("TEST: narrow byte/halfword transfers preserve AXI lane mapping");
    axi_write1(32'h0000_0100, 3'd2, 32'h1122_3344, 4'b1111, 4'h7);
    axi_write1(32'h0000_0101, 3'd0, 32'h0000_AA00, 4'b0010, 4'h8);
    axi_read1_expect_masked(
      32'h0000_0100, 3'd2, 4'h9, 32'h1122_AA44, 32'hFFFF_FFFF
    );

    axi_write1(32'h0000_0102, 3'd1, 32'hBEEF_0000, 4'b1100, 4'hA);
    axi_read1_expect_masked(
      32'h0000_0100, 3'd2, 4'hB, 32'hBEEF_AA44, 32'hFFFF_FFFF
    );
    axi_read1_expect_masked(
      32'h0000_0101, 3'd0, 4'hC, 32'h0000_AA00, 32'h0000_FF00
    );
    axi_read1_expect_masked(
      32'h0000_0102, 3'd1, 4'hD, 32'hBEEF_0000, 32'hFFFF_0000
    );

    if (errors == 0) begin
      $display("REFERENCE SMOKE PASS");
      $finish;
    end else begin
      $fatal(1, "REFERENCE SMOKE FAIL: %0d error(s)", errors);
    end
  end

  initial begin
    #100us;
    $fatal(1, "REFERENCE SMOKE TIMEOUT");
  end
endmodule
