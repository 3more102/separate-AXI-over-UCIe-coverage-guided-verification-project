`timescale 1ns/1ps

module smoke_tb;
  localparam int ADDR_W = 32;
  localparam int DATA_W = 64;
  localparam int ID_W   = 4;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  always #5 clk = ~clk;

  logic [ID_W-1:0] awid;
  logic [ADDR_W-1:0] awaddr;
  logic [7:0] awlen;
  logic [2:0] awsize;
  logic [1:0] awburst;
  logic awvalid, awready;

  logic [DATA_W-1:0] wdata;
  logic [DATA_W/8-1:0] wstrb;
  logic wlast, wvalid, wready;

  logic [ID_W-1:0] bid;
  logic [1:0] bresp;
  logic bvalid, bready;

  logic [ID_W-1:0] arid;
  logic [ADDR_W-1:0] araddr;
  logic [7:0] arlen;
  logic [2:0] arsize;
  logic [1:0] arburst;
  logic arvalid, arready;

  logic [ID_W-1:0] rid;
  logic [DATA_W-1:0] rdata;
  logic [1:0] rresp;
  logic rlast, rvalid, rready;

  logic req_valid, req_ready, req_write;
  logic [ID_W-1:0] req_id;
  logic [ADDR_W-1:0] req_addr;
  logic [7:0] req_len;
  logic [2:0] req_size;
  logic [DATA_W-1:0] req_wdata;
  logic [DATA_W/8-1:0] req_wstrb;

  logic rsp_valid, rsp_ready, rsp_write;
  logic [ID_W-1:0] rsp_id;
  logic [1:0] rsp_resp;
  logic [DATA_W-1:0] rsp_rdata;

  logic allow_req;
  integer errors = 0;
  integer link_accepts = 0;

  axi_ucie_bridge #(
    .ADDR_W(ADDR_W), .DATA_W(DATA_W), .ID_W(ID_W)
  ) dut (
    .clk, .rst_n,
    .s_axi_awid(awid), .s_axi_awaddr(awaddr), .s_axi_awlen(awlen),
    .s_axi_awsize(awsize), .s_axi_awburst(awburst),
    .s_axi_awvalid(awvalid), .s_axi_awready(awready),
    .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wlast(wlast),
    .s_axi_wvalid(wvalid), .s_axi_wready(wready),
    .s_axi_bid(bid), .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
    .s_axi_arid(arid), .s_axi_araddr(araddr), .s_axi_arlen(arlen),
    .s_axi_arsize(arsize), .s_axi_arburst(arburst),
    .s_axi_arvalid(arvalid), .s_axi_arready(arready),
    .s_axi_rid(rid), .s_axi_rdata(rdata), .s_axi_rresp(rresp),
    .s_axi_rlast(rlast), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
    .link_req_valid(req_valid), .link_req_ready(req_ready),
    .link_req_write(req_write), .link_req_id(req_id), .link_req_addr(req_addr),
    .link_req_len(req_len), .link_req_size(req_size),
    .link_req_wdata(req_wdata), .link_req_wstrb(req_wstrb),
    .link_rsp_valid(rsp_valid), .link_rsp_ready(rsp_ready),
    .link_rsp_write(rsp_write), .link_rsp_id(rsp_id),
    .link_rsp_resp(rsp_resp), .link_rsp_rdata(rsp_rdata)
  );

  ucie_mem_endpoint #(
    .ADDR_W(ADDR_W), .DATA_W(DATA_W), .ID_W(ID_W), .DEPTH(256)
  ) endpoint (
    .clk, .rst_n, .allow_req,
    .req_valid, .req_ready, .req_write, .req_id, .req_addr,
    .req_len, .req_size, .req_wdata, .req_wstrb,
    .rsp_valid, .rsp_ready, .rsp_write, .rsp_id, .rsp_resp, .rsp_rdata
  );

  always @(posedge clk)
    if (rst_n && req_valid && req_ready)
      link_accepts <= link_accepts + 1;

  task automatic fail(input string msg);
    begin
      errors = errors + 1;
      $display("ERROR: %s", msg);
    end
  endtask

  task automatic finish_b(
    input logic [ID_W-1:0] id,
    input logic [1:0] expected_resp
  );
    begin
      wait (bvalid === 1'b1);
      if (bid !== id)
        fail($sformatf("BID mismatch exp=%0d got=%0d", id, bid));
      if (bresp !== expected_resp)
        fail($sformatf("BRESP mismatch exp=%0b got=%0b", expected_resp, bresp));

      begin : check_b_stability
        logic [ID_W-1:0] held_bid;
        logic [1:0] held_bresp;
        held_bid = bid;
        held_bresp = bresp;
        repeat (2) begin
          @(posedge clk);
          if (!bvalid || bid !== held_bid || bresp !== held_bresp)
            fail("B response changed while BREADY was low");
        end
      end
      @(negedge clk);
      bready = 1'b1;
      @(posedge clk);
      @(negedge clk);
      bready = 1'b0;
    end
  endtask

  task automatic axi_write(
    input logic [ADDR_W-1:0] addr,
    input logic [DATA_W-1:0] data,
    input logic [ID_W-1:0] id,
    input logic [7:0] len,
    input logic [1:0] expected_resp
  );
    begin
      @(negedge clk);
      awid = id;
      awaddr = addr;
      awlen = len;
      awsize = $clog2(DATA_W/8);
      awburst = 2'b01;
      awvalid = 1'b1;

      wdata = data;
      wstrb = '1;
      wlast = 1'b1;
      wvalid = 1'b1;

      fork
        begin
          do @(posedge clk); while (!awready);
          @(negedge clk);
          awvalid = 1'b0;
        end
        begin
          do @(posedge clk); while (!wready);
          @(negedge clk);
          wvalid = 1'b0;
        end
      join

      finish_b(id, expected_resp);
    end
  endtask

  task automatic axi_write_ordered(
    input logic [ADDR_W-1:0] addr,
    input logic [DATA_W-1:0] data,
    input logic [DATA_W/8-1:0] strb,
    input logic [ID_W-1:0] id,
    input bit w_before_aw
  );
    begin
      if (w_before_aw) begin
        @(negedge clk);
        wdata = data;
        wstrb = strb;
        wlast = 1'b1;
        wvalid = 1'b1;
        do @(posedge clk); while (!wready);
        @(negedge clk);
        wvalid = 1'b0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        awid = id;
        awaddr = addr;
        awlen = 8'd0;
        awsize = $clog2(DATA_W/8);
        awburst = 2'b01;
        awvalid = 1'b1;
        do @(posedge clk); while (!awready);
        @(negedge clk);
        awvalid = 1'b0;
      end else begin
        @(negedge clk);
        awid = id;
        awaddr = addr;
        awlen = 8'd0;
        awsize = $clog2(DATA_W/8);
        awburst = 2'b01;
        awvalid = 1'b1;
        do @(posedge clk); while (!awready);
        @(negedge clk);
        awvalid = 1'b0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        wdata = data;
        wstrb = strb;
        wlast = 1'b1;
        wvalid = 1'b1;
        do @(posedge clk); while (!wready);
        @(negedge clk);
        wvalid = 1'b0;
      end

      finish_b(id, 2'b00);
    end
  endtask

  task automatic axi_write_burst_expect_error(
    input logic [ADDR_W-1:0] addr,
    input logic [ID_W-1:0] id,
    input integer beats
  );
    integer i;
    begin
      @(negedge clk);
      awid = id;
      awaddr = addr;
      awlen = beats - 1;
      awsize = $clog2(DATA_W/8);
      awburst = 2'b01;
      awvalid = 1'b1;
      do @(posedge clk); while (!awready);
      @(negedge clk);
      awvalid = 1'b0;

      for (i = 0; i < beats; i = i + 1) begin
        @(negedge clk);
        wdata = 64'hBAD0_0000_0000_0000 + i;
        wstrb = '1;
        wlast = (i == beats-1);
        wvalid = 1'b1;
        do @(posedge clk); while (!wready);
        @(negedge clk);
        wvalid = 1'b0;
      end

      finish_b(id, 2'b10);
    end
  endtask

  task automatic axi_read(
    input logic [ADDR_W-1:0] addr,
    input logic [ID_W-1:0] id,
    input logic [7:0] len,
    input logic [1:0] expected_resp,
    input logic [DATA_W-1:0] expected_data
  );
    begin
      @(negedge clk);
      arid = id;
      araddr = addr;
      arlen = len;
      arsize = $clog2(DATA_W/8);
      arburst = 2'b01;
      arvalid = 1'b1;

      do @(posedge clk); while (!arready);
      @(negedge clk);
      arvalid = 1'b0;

      wait (rvalid === 1'b1);
      if (rid !== id)
        fail($sformatf("RID mismatch exp=%0d got=%0d", id, rid));
      if (rresp !== expected_resp)
        fail($sformatf("RRESP mismatch exp=%0b got=%0b", expected_resp, rresp));
      if (!rlast)
        fail("RLAST was not asserted");
      if ((expected_resp == 2'b00) && (rdata !== expected_data))
        fail($sformatf("RDATA mismatch exp=%h got=%h", expected_data, rdata));

      begin : check_r_stability
        logic [ID_W-1:0] held_rid;
        logic [DATA_W-1:0] held_rdata;
        logic [1:0] held_rresp;
        logic held_rlast;
        held_rid = rid;
        held_rdata = rdata;
        held_rresp = rresp;
        held_rlast = rlast;
        repeat (2) begin
          @(posedge clk);
          if (!rvalid || rid !== held_rid || rdata !== held_rdata ||
              rresp !== held_rresp || rlast !== held_rlast)
            fail("R response changed while RREADY was low");
        end
      end
      @(negedge clk);
      rready = 1'b1;
      @(posedge clk);
      @(negedge clk);
      rready = 1'b0;
    end
  endtask

  task automatic axi_read_burst_expect_error(
    input logic [ADDR_W-1:0] addr,
    input logic [ID_W-1:0] id,
    input integer beats
  );
    integer i;
    begin
      @(negedge clk);
      arid = id;
      araddr = addr;
      arlen = beats - 1;
      arsize = $clog2(DATA_W/8);
      arburst = 2'b01;
      arvalid = 1'b1;

      do @(posedge clk); while (!arready);
      @(negedge clk);
      arvalid = 1'b0;
      rready = 1'b1;

      for (i = 0; i < beats; i = i + 1) begin
        while (rvalid !== 1'b1)
          @(negedge clk);

        if (rid !== id)
          fail($sformatf("RID mismatch on rejected burst exp=%0d got=%0d", id, rid));
        if (rresp !== 2'b10)
          fail($sformatf("Rejected read beat %0d did not return SLVERR", i));
        if (rdata !== '0)
          fail($sformatf("Rejected read beat %0d returned non-zero data", i));
        if (rlast !== (i == beats-1))
          fail($sformatf("Rejected read RLAST mismatch beat=%0d/%0d", i, beats));

        @(posedge clk);
        @(negedge clk);
      end

      rready = 1'b0;
    end
  endtask

  initial begin
    awid = '0; awaddr = '0; awlen = '0; awsize = '0; awburst = '0; awvalid = 1'b0;
    wdata = '0; wstrb = '0; wlast = 1'b0; wvalid = 1'b0; bready = 1'b0;
    arid = '0; araddr = '0; arlen = '0; arsize = '0; arburst = '0; arvalid = 1'b0;
    rready = 1'b0;
    allow_req = 1'b1;

    repeat (4) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;

    $display("TEST: write/read with response backpressure");
    axi_write(32'h0000_0020, 64'hDEAD_BEEF_CAFE_BABE, 4'h3, 8'd0, 2'b00);
    axi_read (32'h0000_0020, 4'h5, 8'd0, 2'b00, 64'hDEAD_BEEF_CAFE_BABE);

    $display("TEST: explicit W-before-AW and AW-before-W ordering");
    axi_write_ordered(
      32'h0000_0080, 64'h0102_0304_0506_0708, '1, 4'hC, 1'b1
    );
    axi_read(
      32'h0000_0080, 4'hD, 8'd0, 2'b00, 64'h0102_0304_0506_0708
    );
    axi_write_ordered(
      32'h0000_0088, 64'h1112_1314_1516_1718, '1, 4'hE, 1'b0
    );
    axi_read(
      32'h0000_0088, 4'hF, 8'd0, 2'b00, 64'h1112_1314_1516_1718
    );

    $display("TEST: partial write strobes");
    axi_write(
      32'h0000_00A0, 64'h1122_3344_5566_7788, 4'h1, 8'd0, 2'b00
    );
    axi_write_ordered(
      32'h0000_00A0, 64'hFFFF_0000_AAAA_BBBB, 8'h0F, 4'h2, 1'b1
    );
    axi_read(
      32'h0000_00A0, 4'h3, 8'd0, 2'b00, 64'h1122_3344_AAAA_BBBB
    );

    $display("TEST: link request stall");
    allow_req = 1'b0;
    fork
      begin : link_stall_stability
        logic held_write;
        logic [ID_W-1:0] held_id;
        logic [ADDR_W-1:0] held_addr;
        logic [7:0] held_len;
        logic [2:0] held_size;
        logic [DATA_W-1:0] held_wdata;
        logic [DATA_W/8-1:0] held_wstrb;

        wait (req_valid === 1'b1);
        held_write = req_write;
        held_id = req_id;
        held_addr = req_addr;
        held_len = req_len;
        held_size = req_size;
        held_wdata = req_wdata;
        held_wstrb = req_wstrb;

        repeat (6) begin
          @(posedge clk);
          if (!req_valid)
            fail("request did not remain pending during link stall");
          if (req_write !== held_write || req_id !== held_id || req_addr !== held_addr ||
              req_len !== held_len || req_size !== held_size ||
              req_wdata !== held_wdata || req_wstrb !== held_wstrb)
            fail("link request payload changed while stalled");
        end
        @(negedge clk);
        allow_req = 1'b1;
      end
      begin
        axi_write(32'h0000_0040, 64'h0123_4567_89AB_CDEF, 4'h7, 8'd0, 2'b00);
      end
    join
    axi_read(32'h0000_0040, 4'h8, 8'd0, 2'b00, 64'h0123_4567_89AB_CDEF);

    $display("TEST: unsupported bursts are fully drained and rejected locally");
    begin : burst_reject_check
      integer before_count;
      before_count = link_accepts;

      axi_write_burst_expect_error(32'h0000_0060, 4'h9, 3);
      if (link_accepts != before_count)
        fail("unsupported write burst reached the link");

      axi_read_burst_expect_error(32'h0000_0060, 4'hA, 3);
      if (link_accepts != before_count)
        fail("unsupported read burst reached the link");

      axi_write(
        32'h0000_0068, 64'hCAFE_F00D_1234_5678, 4'hB, 8'd0, 2'b00
      );
      axi_read(
        32'h0000_0068, 4'hC, 8'd0, 2'b00, 64'hCAFE_F00D_1234_5678
      );
    end

    $display("TEST: reset recovery");
    @(negedge clk);
    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    axi_read(32'h0000_0020, 4'hB, 8'd0, 2'b00, 64'hDEAD_BEEF_CAFE_BABE);

    if (errors == 0) begin
      $display("SMOKE PASS: %0d link requests accepted", link_accepts);
      $finish;
    end else begin
      $fatal(1, "SMOKE FAIL: %0d error(s)", errors);
    end
  end

  initial begin
    #200000;
    $fatal(1, "SMOKE TIMEOUT");
  end

endmodule
