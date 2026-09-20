module ucie_responder_model #(
  parameter int FLIT_W = 128
) (
  input  logic              clk,
  input  logic              rst_n,
  input  logic              stall_enable,
  input  logic              req_valid,
  output logic              req_ready,
  input  logic [FLIT_W-1:0] req_data,
  output logic              rsp_valid,
  input  logic              rsp_ready,
  output logic [FLIT_W-1:0] rsp_data
);

  localparam logic [3:0] OP_WRITE_REQ = 4'h1;
  localparam logic [3:0] OP_READ_REQ  = 4'h2;
  localparam logic [3:0] OP_WRITE_RSP = 4'h8;
  localparam logic [3:0] OP_READ_RSP  = 4'h9;

  logic [15:0] lfsr_q;
  logic pending_q;
  logic [FLIT_W-1:0] rsp_q;

  assign req_ready = rst_n && !pending_q && (!stall_enable || lfsr_q[0]);
  assign rsp_valid = pending_q;
  assign rsp_data = rsp_q;

  function automatic logic [1:0] response_for_addr(input logic [31:0] addr);
    return (addr[31:28] == 4'hF) ? 2'b10 : 2'b00;
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lfsr_q <= 16'h1ACE;
      pending_q <= 1'b0;
      rsp_q <= '0;
    end else begin
      lfsr_q <= {lfsr_q[14:0], lfsr_q[15] ^ lfsr_q[13] ^ lfsr_q[12] ^ lfsr_q[10]};

      if (req_valid && req_ready) begin
        rsp_q <= '0;
        unique case (req_data[127:124])
          OP_WRITE_REQ: begin
            rsp_q[127:124] <= OP_WRITE_RSP;
            rsp_q[123:120] <= req_data[123:120];
            rsp_q[55:54] <= response_for_addr(req_data[119:88]);
            pending_q <= 1'b1;
          end
          OP_READ_REQ: begin
            rsp_q[127:124] <= OP_READ_RSP;
            rsp_q[123:120] <= req_data[123:120];
            rsp_q[87:56] <= req_data[119:88] ^ 32'hA5A5_5A5A;
            rsp_q[55:54] <= response_for_addr(req_data[119:88]);
            pending_q <= 1'b1;
          end
          default: pending_q <= 1'b0;
        endcase
      end

      if (rsp_valid && rsp_ready)
        pending_q <= 1'b0;
    end
  end
endmodule
