interface ucie_link_if #(
  parameter int FLIT_W = 128
) (
  input logic clk,
  input logic rst_n
);
  logic tx_valid;
  logic tx_ready;
  logic [FLIT_W-1:0] tx_data;

  logic rx_valid;
  logic rx_ready;
  logic [FLIT_W-1:0] rx_data;
endinterface
