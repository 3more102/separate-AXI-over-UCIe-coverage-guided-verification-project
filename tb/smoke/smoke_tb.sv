`timescale 1ns/1ps

module smoke_tb;
  localparam int ADDR_W = 32;
  localparam int DATA_W = 64;
  localparam int ID_W   = 4;
  localparam logic [1:0] BURST_FIXED = 2'b00;
  localparam logic [1:0] BURST_INCR  = 2'b01;
  localparam logic [1:0] BURST_WRAP  = 2'b10;

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

  task automatic axi_write_burst(
    input logic [ADDR_W-1:0] addr,
    input logic [DATA_W-1:0] base_data,
    input logic [ID_W-1:0] id,
    input logic [7:0] len,
    input logic [1:0] burst,
    input logic [1:0] expected_resp
  );
    integer beat;
    begin
      @(negedge clk);
      awid    = id;
      awaddr  = addr;
      awlen   = len;
      awsize  = $clog2(DATA_W/8);
      awburst = burst;
      awvalid = 1'b1;

      fork
        begin
          do @(posedge clk); while (!awready);
          @(negedge clk);
          awvalid = 1'b0;
        end
        begin
          for (beat = 0; beat <= len; beat = beat + 1) begin
            wdata  = base_data + beat;
            wstrb  = '1;
            wlast  = (beat == len);
            wvalid = 1'b1;
            do @(posedge clk); while (!wready);
            @(negedge clk);
            wvalid = 1'b0;
          end
          wlast = 1'b0;
        end
      join

      wait (bvalid === 1'b1);
      if (bid !== id)
        fail($sformatf("BID mismatch exp=%0d got=%0d", id, bid));
      if (bresp !== expected_resp)
        fail($sformatf("BRESP mismatch exp=%0b got=%0b", expected_resp, bresp));

      repeat (2) @(posedge clk);
      @(negedge clk);
      bready = 1'b1;
      @(posedge clk);
      @(negedge clk);
      bready = 1'b0;
    end
  endtask

  task automatic axi_read_burst(
    input logic [ADDR_W-1:0] addr,
    input logic [DATA_W-1:0] base_data,
    input logic [ID_W-1:0] id,
    input logic [7:0] len,
    input logic [1:0] burst,
    input logic [1:0] expected_resp
  );
    integer beat;
    logic [DATA_W-1:0] expected_data;
    begin
      @(negedge clk);
      arid    = id;
      araddr  = addr;
      arlen   = len;
      arsize  = $clog2(DATA_W/8);
      arburst = burst;
      arvalid = 1'b1;

      do @(posedge clk); while (!arready);
      @(negedge clk);
      arvalid = 1'b0;

      for (beat = 0; beat <= len; beat = beat + 1) begin
        wait (rvalid === 1'b1);
        expected_data = (burst == BURST_FIXED) ? (base_data + len) : (base_data + beat);

        if (rid !== id)
          fail($sformatf("RID mismatch beat=%0d exp=%0d got=%0d", beat, id, rid));
        if (rresp !== expected_resp)
          fail($sformatf("RRESP mismatch beat=%0d exp=%0b got=%0b", beat, expected_resp, rresp));
        if (rlast !== (beat == len))
          fail($sformatf("RLAST mismatch beat=%0d len=%0d rlast=%0b", beat, len, rlast));
        if ((expected_resp == 2'b00) && (rdata !== expected_data))
          fail($sformatf("RDATA mismatch beat=%0d exp=%h got=%h", beat, expected_data, rdata));

        repeat ((beat % 2) + 1) @(posedge clk);
        @(negedge clk);
        rready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        rready = 1'b0;
      end
    end
  endtask

  task automatic axi_read_error(
    input logic [ADDR_W-1:0] addr,
    input logic [ID_W-1:0] id,
    input logic [7:0] len,
    input logic [1:0] burst
  );
    begin
      @(negedge clk);
      arid    = id;
      araddr  = addr;
      arlen   = len;
      arsize  = $clog2(DATA_W/8);
      arburst = burst;
      arvalid = 1'b1;

      do @(posedge clk); while (!arready);
      @(negedge clk);
      arvalid = 1'b0;

      wait (rvalid === 1'b1);
      if (rid !== id)
        fail($sformatf("RID mismatch for rejected read exp=%0d got=%0d", id, rid));
      if (rresp !== 2'b10)
        fail($sformatf("Rejected read did not return SLVERR: %0b", rresp));
      if (!rlast)
        fail("Rejected read must terminate with RLAST");

      @(negedge clk);
      rready = 1'b1;
      @(posedge clk);
      @(negedge clk);
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

    $display("TEST: single-beat write/read with response backpressure");
    axi_write_burst(32'h0000_0020, 64'hDEAD_BEEF_CAFE_BABE, 4'h3, 8'd0, BURST_INCR, 2'b00);
    axi_read_burst (32'h0000_0020, 64'hDEAD_BEEF_CAFE_BABE, 4'h5, 8'd0, BURST_INCR, 2'b00);

    $display("TEST: four-beat INCR burst packetization");
    axi_write_burst(32'h0000_0080, 64'h1000_0000_0000_0000, 4'h4, 8'd3, BURST_INCR, 2'b00);
    axi_read_burst (32'h0000_0080, 64'h1000_0000_0000_0000, 4'h6, 8'd3, BURST_INCR, 2'b00);

    $display("TEST: three-beat FIXED burst packetization");
    axi_write_burst(32'h0000_0100, 64'h2000_0000_0000_0000, 4'h7, 8'd2, BURST_FIXED, 2'b00);
    axi_read_burst (32'h0000_0100, 64'h2000_0000_0000_0000, 4'h8, 8'd2, BURST_FIXED, 2'b00);

    $display("TEST: link request stall inside burst");
    allow_req = 1'b0;
    fork
      begin
        repeat (6) @(posedge clk);
        if (!req_valid)
          fail("request did not remain pending during link stall");
        @(negedge clk);
        allow_req = 1'b1;
      end
      begin
        axi_write_burst(32'h0000_0140, 64'h3000_0000_0000_0000, 4'h9, 8'd1, BURST_INCR, 2'b00);
      end
    join
    axi_read_burst(32'h0000_0140, 64'h3000_0000_0000_0000, 4'hA, 8'd1, BURST_INCR, 2'b00);

    $display("TEST: unsupported WRAP burst rejected locally");
    begin : burst_reject_check
      integer before_count;
      before_count = link_accepts;
      axi_write_burst(32'h0000_0180, 64'hA5A5_A5A5_A5A5_A5A5, 4'hB, 8'd1, BURST_WRAP, 2'b10);
      if (link_accepts != before_count)
        fail("unsupported WRAP write reached the link");
      axi_read_error(32'h0000_0180, 4'hC, 8'd2, BURST_WRAP);
      if (link_accepts != before_count)
        fail("unsupported WRAP read reached the link");
    end

    $display("TEST: reset recovery preserves endpoint memory");
    @(negedge clk);
    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    axi_read_burst(32'h0000_0020, 64'hDEAD_BEEF_CAFE_BABE, 4'hD, 8'd0, BURST_INCR, 2'b00);

    if (errors == 0) begin
      $display("SMOKE PASS: %0d link beat requests accepted", link_accepts);
      $finish;
    end else begin
      $fatal(1, "SMOKE FAIL: %0d error(s)", errors);
    end
  end

endmodule
