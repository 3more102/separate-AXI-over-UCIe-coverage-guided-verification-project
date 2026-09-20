module axi_memory_slave #(
  parameter int ID_W      = 4,
  parameter int ADDR_W    = 32,
  parameter int DATA_W    = 32,
  parameter int MEM_BYTES = 4096
) (
  input logic clk,
  input logic rst_n,
  axi_if.slave axi
);
  localparam int STRB_W = DATA_W/8;

  byte unsigned mem [0:MEM_BYTES-1];

  logic wr_active;
  logic [ID_W-1:0] wr_id;
  logic [ADDR_W-1:0] wr_addr;
  logic [2:0] wr_size;
  logic [1:0] wr_burst;
  logic [8:0] wr_beats_left;
  logic [ID_W-1:0] bid_q;
  logic [1:0] bresp_q;
  logic bvalid_q;

  logic rd_active;
  logic [ID_W-1:0] rd_id;
  logic [ADDR_W-1:0] rd_addr;
  logic [2:0] rd_size;
  logic [1:0] rd_burst;
  logic [8:0] rd_beats_left;
  logic [DATA_W-1:0] rdata_q;
  logic [ID_W-1:0] rid_q;
  logic [1:0] rresp_q;
  logic rlast_q;
  logic rvalid_q;

  function automatic [DATA_W-1:0] read_word(input logic [ADDR_W-1:0] addr);
    int i;
    begin
      read_word = '0;
      for (i = 0; i < STRB_W; i++)
        read_word[i*8 +: 8] = mem[(addr + i) % MEM_BYTES];
    end
  endfunction

  assign axi.awready = !wr_active && !bvalid_q;
  assign axi.wready  = wr_active && !bvalid_q;
  assign axi.bid     = bid_q;
  assign axi.bresp   = bresp_q;
  assign axi.bvalid  = bvalid_q;

  assign axi.arready = !rd_active && !rvalid_q;
  assign axi.rid     = rid_q;
  assign axi.rdata   = rdata_q;
  assign axi.rresp   = rresp_q;
  assign axi.rlast   = rlast_q;
  assign axi.rvalid  = rvalid_q;

  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_active      <= 1'b0;
      wr_id          <= '0;
      wr_addr        <= '0;
      wr_size        <= '0;
      wr_burst       <= '0;
      wr_beats_left  <= '0;
      bid_q          <= '0;
      bresp_q        <= 2'b00;
      bvalid_q       <= 1'b0;

      rd_active      <= 1'b0;
      rd_id          <= '0;
      rd_addr        <= '0;
      rd_size        <= '0;
      rd_burst       <= '0;
      rd_beats_left  <= '0;
      rid_q          <= '0;
      rdata_q        <= '0;
      rresp_q        <= 2'b00;
      rlast_q        <= 1'b0;
      rvalid_q       <= 1'b0;
    end else begin
      if (axi.awvalid && axi.awready) begin
        wr_active     <= 1'b1;
        wr_id         <= axi.awid;
        wr_addr       <= axi.awaddr;
        wr_size       <= axi.awsize;
        wr_burst      <= axi.awburst;
        wr_beats_left <= {1'b0, axi.awlen} + 9'd1;
      end

      if (axi.wvalid && axi.wready) begin
        for (i = 0; i < STRB_W; i++) begin
          if (axi.wstrb[i])
            mem[(wr_addr + i) % MEM_BYTES] <= axi.wdata[i*8 +: 8];
        end

        if (axi.wlast || (wr_beats_left == 9'd1)) begin
          wr_active     <= 1'b0;
          wr_beats_left <= '0;
          bid_q         <= wr_id;
          bresp_q       <= (axi.wlast == (wr_beats_left == 9'd1)) ? 2'b00 : 2'b10;
          bvalid_q      <= 1'b1;
        end else begin
          if (wr_burst == 2'b01)
            wr_addr <= wr_addr + ({{(ADDR_W-1){1'b0}},1'b1} << wr_size);
          wr_beats_left <= wr_beats_left - 9'd1;
        end
      end

      if (bvalid_q && axi.bready)
        bvalid_q <= 1'b0;

      if (axi.arvalid && axi.arready) begin
        rd_active     <= 1'b1;
        rd_id         <= axi.arid;
        rd_addr       <= axi.araddr;
        rd_size       <= axi.arsize;
        rd_burst      <= axi.arburst;
        rd_beats_left <= {1'b0, axi.arlen} + 9'd1;
      end

      if (rd_active && !rvalid_q) begin
        rid_q   <= rd_id;
        rdata_q <= read_word(rd_addr);
        rresp_q <= 2'b00;
        rlast_q <= (rd_beats_left == 9'd1);
        rvalid_q <= 1'b1;
      end

      if (rvalid_q && axi.rready) begin
        rvalid_q <= 1'b0;
        if (rlast_q) begin
          rd_active     <= 1'b0;
          rd_beats_left <= '0;
          rlast_q       <= 1'b0;
        end else begin
          if (rd_burst == 2'b01)
            rd_addr <= rd_addr + ({{(ADDR_W-1){1'b0}},1'b1} << rd_size);
          rd_beats_left <= rd_beats_left - 9'd1;
        end
      end
    end
  end
endmodule
