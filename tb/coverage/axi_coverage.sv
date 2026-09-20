module axi_coverage (
  axi_if.monitor axi,
  input logic req_stall,
  input logic rsp_stall
);
  logic [7:0] awlen_s;
  logic [7:0] arlen_s;
  logic [1:0] awburst_s;
  logic [1:0] arburst_s;
  logic       write_hs;
  logic       read_hs;
  logic       req_stall_s;
  logic       rsp_stall_s;

  covergroup cg @(posedge axi.aclk);
    option.per_instance = 1;

    cp_write: coverpoint write_hs { bins no = {0}; bins yes = {1}; }
    cp_read : coverpoint read_hs  { bins no = {0}; bins yes = {1}; }

    cp_awlen: coverpoint awlen_s iff (write_hs) {
      bins single = {0};
      bins short  = {[1:3]};
      bins medium = {[4:15]};
      bins long   = {[16:255]};
    }

    cp_arlen: coverpoint arlen_s iff (read_hs) {
      bins single = {0};
      bins short  = {[1:3]};
      bins medium = {[4:15]};
      bins long   = {[16:255]};
    }

    cp_awburst: coverpoint awburst_s iff (write_hs) {
      bins fixed = {2'b00};
      bins incr  = {2'b01};
      bins wrap  = {2'b10};
      illegal_bins reserved = {2'b11};
    }

    cp_arburst: coverpoint arburst_s iff (read_hs) {
      bins fixed = {2'b00};
      bins incr  = {2'b01};
      bins wrap  = {2'b10};
      illegal_bins reserved = {2'b11};
    }

    cp_req_stall: coverpoint req_stall_s;
    cp_rsp_stall: coverpoint rsp_stall_s;

    x_write_flow: cross cp_write, cp_req_stall;
    x_read_flow : cross cp_read, cp_req_stall;
  endgroup

  assign write_hs   = axi.awvalid && axi.awready;
  assign read_hs    = axi.arvalid && axi.arready;
  assign awlen_s    = axi.awlen;
  assign arlen_s    = axi.arlen;
  assign awburst_s  = axi.awburst;
  assign arburst_s  = axi.arburst;
  assign req_stall_s = req_stall;
  assign rsp_stall_s = rsp_stall;

  cg coverage = new();

endmodule
