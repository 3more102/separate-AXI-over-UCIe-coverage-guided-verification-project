`timescale 1ns/1ps

module response_integrity_tb;
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

  logic link_req_valid, link_req_ready, link_req_write;
  logic [ID_W-1:0] link_req_id;
  logic [ADDR_W-1:0] link_req_addr;
  logic [7:0] link_req_len;
  logic [2:0] link_req_size;
  logic [DATA_W-1:0] link_req_wdata;
  logic [DATA_W/8-1:0] link_req_wstrb;

  logic link_rsp_valid, link_rsp_ready, link_rsp_write;
  logic [ID_W-1:0] link_rsp_id;
  logic [1:0] link_rsp_resp;
  logic [DATA_W-1:0] link_rsp_rdata;

  integer errors = 0;

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
    .link_req_valid, .link_req_ready, .link_req_write, .link_req_id,
    .link_req_addr, .link_req_len, .link_req_size,
    .link_req_wdata, .link_req_wstrb,
    .link_rsp_valid, .link_rsp_ready, .link_rsp_write, .link_rsp_id,
    .link_rsp_resp, .link_rsp_rdata
  );

  task automatic fail(input string msg);
    begin
      errors = errors + 1;
      $display("ERROR: %s", msg);
    end
  endtask

  task automatic issue_write(
    input logic [ID_W-1:0] id,
    input logic [ADDR_W-1:0] addr,
    input logic [DATA_W-1:0] data
  );
    begin
      @(negedge clk);
      awid = id;
      awaddr = addr;
      awlen = 8'd0;
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

      wait (link_req_valid === 1'b1);
      if (!link_req_write)
        fail("write request was emitted as read");
      if (link_req_id !== id)
        fail($sformatf("link write ID mismatch exp=%0h got=%0h", id, link_req_id));
      @(posedge clk);
      @(negedge clk);
    end
  endtask

  task automatic issue_read(
    input logic [ID_W-1:0] id,
    input logic [ADDR_W-1:0] addr
  );
    begin
      @(negedge clk);
      arid = id;
      araddr = addr;
      arlen = 8'd0;
      arsize = $clog2(DATA_W/8);
      arburst = 2'b01;
      arvalid = 1'b1;

      do @(posedge clk); while (!arready);
      @(negedge clk);
      arvalid = 1'b0;

      wait (link_req_valid === 1'b1);
      if (link_req_write)
        fail("read request was emitted as write");
      if (link_req_id !== id)
        fail($sformatf("link read ID mismatch exp=%0h got=%0h", id, link_req_id));
      @(posedge clk);
      @(negedge clk);
    end
  endtask

  task automatic send_link_response(
    input logic is_write,
    input logic [ID_W-1:0] id,
    input logic [1:0] resp,
    input logic [DATA_W-1:0] data
  );
    begin
      link_rsp_write = is_write;
      link_rsp_id = id;
      link_rsp_resp = resp;
      link_rsp_rdata = data;
      link_rsp_valid = 1'b1;
      do @(posedge clk); while (!link_rsp_ready);
      @(negedge clk);
      link_rsp_valid = 1'b0;
    end
  endtask

  task automatic consume_b;
    begin
      @(negedge clk);
      bready = 1'b1;
      @(posedge clk);
      @(negedge clk);
      bready = 1'b0;
    end
  endtask

  task automatic consume_r;
    begin
      @(negedge clk);
      rready = 1'b1;
      @(posedge clk);
      @(negedge clk);
      rready = 1'b0;
    end
  endtask

  initial begin
    awid='0; awaddr='0; awlen='0; awsize='0; awburst='0; awvalid=1'b0;
    wdata='0; wstrb='0; wlast=1'b0; wvalid=1'b0;
    bready=1'b0;
    arid='0; araddr='0; arlen='0; arsize='0; arburst='0; arvalid=1'b0;
    rready=1'b0;

    link_req_ready=1'b1;
    link_rsp_valid=1'b0;
    link_rsp_write=1'b0;
    link_rsp_id='0;
    link_rsp_resp='0;
    link_rsp_rdata='0;

    repeat (4) @(posedge clk);
    @(negedge clk);
    rst_n=1'b1;

    $display("TEST: mismatched write response ID is contained");
    issue_write(4'h3, 32'h100, 64'h0123_4567_89AB_CDEF);
    send_link_response(1'b1, 4'h9, 2'b00, '0);
    wait (bvalid === 1'b1);
    if (bid !== 4'h3)
      fail($sformatf("BID was not restored to expected ID: %0h", bid));
    if (bresp !== 2'b10)
      fail($sformatf("mismatched write ID did not become SLVERR: %0b", bresp));
    if (rvalid)
      fail("mismatched write response leaked onto R channel");
    consume_b();

    $display("TEST: mismatched response direction is contained");
    issue_write(4'h4, 32'h108, 64'hCAFE_BABE_0000_0001);
    send_link_response(1'b0, 4'h4, 2'b00, 64'hDEAD_BEEF_DEAD_BEEF);
    wait (bvalid === 1'b1);
    if (bid !== 4'h4)
      fail($sformatf("direction mismatch changed BID: %0h", bid));
    if (bresp !== 2'b10)
      fail($sformatf("direction mismatch did not become SLVERR: %0b", bresp));
    if (rvalid)
      fail("direction mismatch was routed to R channel");
    consume_b();

    $display("TEST: mismatched read response ID is contained");
    issue_read(4'h5, 32'h200);
    send_link_response(1'b0, 4'h7, 2'b00, 64'hFFFF_EEEE_DDDD_CCCC);
    wait (rvalid === 1'b1);
    if (rid !== 4'h5)
      fail($sformatf("RID was not restored to expected ID: %0h", rid));
    if (rresp !== 2'b10)
      fail($sformatf("mismatched read ID did not become SLVERR: %0b", rresp));
    if (rdata !== '0)
      fail($sformatf("corrupt read response data was exposed: %h", rdata));
    if (!rlast)
      fail("contained read response did not assert RLAST");
    if (bvalid)
      fail("mismatched read response leaked onto B channel");
    consume_r();

    $display("TEST: valid read response passes through unchanged");
    issue_read(4'h6, 32'h208);
    send_link_response(1'b0, 4'h6, 2'b00, 64'h1122_3344_5566_7788);
    wait (rvalid === 1'b1);
    if (rid !== 4'h6 || rresp !== 2'b00 ||
        rdata !== 64'h1122_3344_5566_7788 || !rlast)
      fail("valid read response was not preserved");
    consume_r();

    if (errors == 0) begin
      $display("RESPONSE INTEGRITY PASS");
      $finish;
    end else begin
      $fatal(1, "RESPONSE INTEGRITY FAIL: %0d error(s)", errors);
    end
  end

  initial begin
    #100000;
    $fatal(1, "RESPONSE INTEGRITY TIMEOUT");
  end
endmodule
