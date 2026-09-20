`timescale 1ns/1ps

module link_protocol_checker_tb;
  localparam int ADDR_W = 32;
  localparam int DATA_W = 64;
  localparam int ID_W   = 4;

  logic clk = 1'b0;
  logic rst_n;
  always #5 clk = ~clk;

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
  logic error_seen;

  link_protocol_checker #(
    .ADDR_W(ADDR_W), .DATA_W(DATA_W), .ID_W(ID_W)
  ) dut (
    .clk, .rst_n,
    .req_valid, .req_ready, .req_write, .req_id, .req_addr,
    .req_len, .req_size, .req_wdata, .req_wstrb,
    .rsp_valid, .rsp_ready, .rsp_write, .rsp_id, .rsp_resp, .rsp_rdata,
    .error_seen
  );

  task automatic drive_idle;
    begin
      req_valid = 0; req_ready = 0; req_write = 0; req_id = '0;
      req_addr = '0; req_len = '0; req_size = 3'd3;
      req_wdata = '0; req_wstrb = '0;
      rsp_valid = 0; rsp_ready = 0; rsp_write = 0; rsp_id = '0;
      rsp_resp = 2'b00; rsp_rdata = '0;
    end
  endtask

  task automatic reset_checker;
    begin
      @(negedge clk);
      drive_idle();
      rst_n = 1'b0;
      repeat (2) @(posedge clk);
      @(negedge clk);
      rst_n = 1'b1;
    end
  endtask

  task automatic accept_request(input logic wr, input logic [ID_W-1:0] id);
    begin
      @(negedge clk);
      req_valid = 1'b1;
      req_ready = 1'b0;
      req_write = wr;
      req_id = id;
      req_addr = 32'h100;
      req_len = 0;
      req_size = 3'd3;
      req_wdata = 64'h0123_4567_89ab_cdef;
      req_wstrb = '1;
      repeat (2) @(posedge clk);
      @(negedge clk);
      req_ready = 1'b1;
      @(posedge clk);
      @(negedge clk);
      req_valid = 1'b0;
      req_ready = 1'b0;
    end
  endtask

  initial begin
    rst_n = 1'b0;
    drive_idle();

    // Positive case: both directions may stall, but VALID and payload stay stable.
    reset_checker();
    accept_request(1'b1, 4'h3);
    @(negedge clk);
    rsp_valid = 1'b1;
    rsp_ready = 1'b0;
    rsp_write = 1'b1;
    rsp_id = 4'h3;
    rsp_resp = 2'b00;
    rsp_rdata = '0;
    repeat (2) @(posedge clk);
    @(negedge clk);
    rsp_ready = 1'b1;
    @(posedge clk);
    @(negedge clk);
    rsp_valid = 1'b0;
    rsp_ready = 1'b0;
    if (error_seen)
      $fatal(1, "checker rejected a legal stalled transaction");

    // Negative case: response ID must match the outstanding request.
    reset_checker();
    accept_request(1'b0, 4'h5);
    @(negedge clk);
    rsp_valid = 1'b1;
    rsp_ready = 1'b0;
    rsp_write = 1'b0;
    rsp_id = 4'h6;
    rsp_resp = 2'b00;
    rsp_rdata = 64'h55aa;
    @(posedge clk);
    @(negedge clk);
    if (!error_seen)
      $fatal(1, "checker failed to detect a response-ID mismatch");

    // Negative case: request payload must remain stable during backpressure.
    reset_checker();
    @(negedge clk);
    req_valid = 1'b1;
    req_ready = 1'b0;
    req_write = 1'b1;
    req_id = 4'h7;
    req_addr = 32'h200;
    req_len = 0;
    req_size = 3'd3;
    req_wdata = 64'h1111_2222_3333_4444;
    req_wstrb = '1;
    @(posedge clk);
    @(negedge clk);
    req_addr = 32'h208;
    @(posedge clk);
    @(negedge clk);
    if (!error_seen)
      $fatal(1, "checker failed to detect request-payload instability");

    $display("LINK CHECKER TEST PASS");
    $finish;
  end

  initial begin
    #10000;
    $fatal(1, "LINK CHECKER TEST TIMEOUT");
  end
endmodule
