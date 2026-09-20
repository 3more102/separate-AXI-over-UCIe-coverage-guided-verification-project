package axi_ucie_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef enum bit {AXI_READ, AXI_WRITE} axi_kind_e;

  class axi_txn extends uvm_sequence_item;
    rand axi_kind_e kind;
    rand bit [3:0]  id;
    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand bit [3:0]  strb;
    rand bit        aw_first;
    rand bit        resp_backpressure;

    bit [1:0]  resp;
    bit [31:0] read_data;

    constraint c_align { addr[1:0] == 2'b00; }
    constraint c_strb  { strb != 4'b0000; }

    `uvm_object_utils_begin(axi_txn)
      `uvm_field_enum(axi_kind_e, kind, UVM_DEFAULT)
      `uvm_field_int(id, UVM_DEFAULT)
      `uvm_field_int(addr, UVM_DEFAULT)
      `uvm_field_int(data, UVM_DEFAULT)
      `uvm_field_int(strb, UVM_DEFAULT)
      `uvm_field_int(aw_first, UVM_DEFAULT)
      `uvm_field_int(resp_backpressure, UVM_DEFAULT)
      `uvm_field_int(resp, UVM_DEFAULT)
      `uvm_field_int(read_data, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "axi_txn");
      super.new(name);
    endfunction
  endclass

  class ucie_flit extends uvm_sequence_item;
    bit is_tx;
    bit [127:0] data;

    `uvm_object_utils_begin(ucie_flit)
      `uvm_field_int(is_tx, UVM_DEFAULT)
      `uvm_field_int(data, UVM_HEX)
    `uvm_object_utils_end

    function new(string name = "ucie_flit");
      super.new(name);
    endfunction
  endclass

  class axi_sequencer extends uvm_sequencer #(axi_txn);
    `uvm_component_utils(axi_sequencer)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class axi_driver extends uvm_driver #(axi_txn);
    `uvm_component_utils(axi_driver)
    virtual axi_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "axi_if was not provided to axi_driver")
    endfunction

    task drive_aw(axi_txn tr);
      @(posedge vif.aclk);
      vif.awid    <= tr.id;
      vif.awaddr  <= tr.addr;
      vif.awlen   <= 8'd0;
      vif.awsize  <= 3'd2;
      vif.awburst <= 2'b01;
      vif.awvalid <= 1'b1;
      do @(posedge vif.aclk); while (!vif.awready);
      vif.awvalid <= 1'b0;
    endtask

    task drive_w(axi_txn tr);
      @(posedge vif.aclk);
      vif.wdata  <= tr.data;
      vif.wstrb  <= tr.strb;
      vif.wlast  <= 1'b1;
      vif.wvalid <= 1'b1;
      do @(posedge vif.aclk); while (!vif.wready);
      vif.wvalid <= 1'b0;
    endtask

    task drive_write(axi_txn tr);
      if (tr.aw_first) begin
        drive_aw(tr);
        repeat ($urandom_range(0, 2)) @(posedge vif.aclk);
        drive_w(tr);
      end else begin
        drive_w(tr);
        repeat ($urandom_range(0, 2)) @(posedge vif.aclk);
        drive_aw(tr);
      end

      if (tr.resp_backpressure) begin
        vif.bready <= 1'b0;
        repeat (2) @(posedge vif.aclk);
      end
      vif.bready <= 1'b1;
      do @(posedge vif.aclk); while (!vif.bvalid);
      tr.resp = vif.bresp;
    endtask

    task drive_read(axi_txn tr);
      @(posedge vif.aclk);
      vif.arid    <= tr.id;
      vif.araddr  <= tr.addr;
      vif.arlen   <= 8'd0;
      vif.arsize  <= 3'd2;
      vif.arburst <= 2'b01;
      vif.arvalid <= 1'b1;
      do @(posedge vif.aclk); while (!vif.arready);
      vif.arvalid <= 1'b0;

      if (tr.resp_backpressure) begin
        vif.rready <= 1'b0;
        repeat (2) @(posedge vif.aclk);
      end
      vif.rready <= 1'b1;
      do @(posedge vif.aclk); while (!vif.rvalid);
      tr.resp = vif.rresp;
      tr.read_data = vif.rdata;
    endtask

    task run_phase(uvm_phase phase);
      vif.awvalid <= 1'b0;
      vif.wvalid  <= 1'b0;
      vif.bready  <= 1'b1;
      vif.arvalid <= 1'b0;
      vif.rready  <= 1'b1;
      wait (vif.aresetn === 1'b1);

      forever begin
        seq_item_port.get_next_item(req);
        if (req.kind == AXI_WRITE)
          drive_write(req);
        else
          drive_read(req);
        seq_item_port.item_done();
      end
    endtask
  endclass

  class axi_monitor extends uvm_component;
    `uvm_component_utils(axi_monitor)
    virtual axi_if vif;
    uvm_analysis_port #(axi_txn) ap;

    bit aw_seen_q;
    bit w_seen_q;
    bit rd_seen_q;
    bit aw_first_q;
    bit [3:0] wr_id_q;
    bit [31:0] wr_addr_q;
    bit [31:0] wr_data_q;
    bit [3:0] wr_strb_q;
    bit [3:0] rd_id_q;
    bit [31:0] rd_addr_q;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "axi_if was not provided to axi_monitor")
    endfunction

    task run_phase(uvm_phase phase);
      axi_txn tr;
      forever begin
        @(posedge vif.aclk);
        if (!vif.aresetn) begin
          aw_seen_q = 1'b0;
          w_seen_q  = 1'b0;
          rd_seen_q = 1'b0;
        end else begin
          if (vif.awvalid && vif.awready) begin
            wr_id_q = vif.awid;
            wr_addr_q = vif.awaddr;
            if (!w_seen_q)
              aw_first_q = 1'b1;
            aw_seen_q = 1'b1;
          end

          if (vif.wvalid && vif.wready) begin
            wr_data_q = vif.wdata;
            wr_strb_q = vif.wstrb;
            if (!aw_seen_q)
              aw_first_q = 1'b0;
            w_seen_q = 1'b1;
          end

          if (vif.bvalid && vif.bready && aw_seen_q && w_seen_q) begin
            if (vif.bid !== wr_id_q)
              `uvm_error("AXI_ID", $sformatf("BID %0h != AWID %0h", vif.bid, wr_id_q))
            tr = axi_txn::type_id::create("wr_tr");
            tr.kind = AXI_WRITE;
            tr.id = wr_id_q;
            tr.addr = wr_addr_q;
            tr.data = wr_data_q;
            tr.strb = wr_strb_q;
            tr.aw_first = aw_first_q;
            tr.resp = vif.bresp;
            ap.write(tr);
            aw_seen_q = 1'b0;
            w_seen_q = 1'b0;
          end

          if (vif.arvalid && vif.arready) begin
            rd_id_q = vif.arid;
            rd_addr_q = vif.araddr;
            rd_seen_q = 1'b1;
          end

          if (vif.rvalid && vif.rready && rd_seen_q) begin
            if (vif.rid !== rd_id_q)
              `uvm_error("AXI_ID", $sformatf("RID %0h != ARID %0h", vif.rid, rd_id_q))
            tr = axi_txn::type_id::create("rd_tr");
            tr.kind = AXI_READ;
            tr.id = rd_id_q;
            tr.addr = rd_addr_q;
            tr.resp = vif.rresp;
            tr.read_data = vif.rdata;
            ap.write(tr);
            rd_seen_q = 1'b0;
          end
        end
      end
    endtask
  endclass

  class ucie_monitor extends uvm_component;
    `uvm_component_utils(ucie_monitor)
    virtual ucie_link_if vif;
    uvm_analysis_port #(ucie_flit) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ucie_link_if)::get(this, "", "ucie_vif", vif))
        `uvm_fatal("NOVIF", "ucie_link_if was not provided to ucie_monitor")
    endfunction

    task run_phase(uvm_phase phase);
      ucie_flit flit;
      forever begin
        @(posedge vif.clk);
        if (vif.rst_n) begin
          if (vif.tx_valid && vif.tx_ready) begin
            flit = ucie_flit::type_id::create("tx_flit");
            flit.is_tx = 1'b1;
            flit.data = vif.tx_data;
            ap.write(flit);
          end
          if (vif.rx_valid && vif.rx_ready) begin
            flit = ucie_flit::type_id::create("rx_flit");
            flit.is_tx = 1'b0;
            flit.data = vif.rx_data;
            ap.write(flit);
          end
        end
      end
    endtask
  endclass

  class axi_ucie_scoreboard extends uvm_component;
    `uvm_component_utils(axi_ucie_scoreboard)

    uvm_tlm_analysis_fifo #(axi_txn) axi_fifo;
    uvm_tlm_analysis_fifo #(ucie_flit) ucie_fifo;
    bit [127:0] write_req_q[$];
    bit [127:0] read_req_q[$];

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      axi_fifo = new("axi_fifo", this);
      ucie_fifo = new("ucie_fifo", this);
    endfunction

    function automatic bit [1:0] expected_resp(bit [31:0] addr);
      return (addr[31:28] == 4'hF) ? 2'b10 : 2'b00;
    endfunction

    task consume_ucie();
      ucie_flit flit;
      forever begin
        ucie_fifo.get(flit);
        if (flit.is_tx) begin
          case (flit.data[127:124])
            4'h1: write_req_q.push_back(flit.data);
            4'h2: read_req_q.push_back(flit.data);
            default: `uvm_error("UCIE_OPCODE",
              $sformatf("Unexpected request opcode 0x%0h", flit.data[127:124]))
          endcase
        end
      end
    endtask

    task consume_axi();
      axi_txn tr;
      bit [127:0] flit;
      bit [1:0] exp_resp;
      forever begin
        axi_fifo.get(tr);
        exp_resp = expected_resp(tr.addr);

        if (tr.kind == AXI_WRITE) begin
          if (write_req_q.size() == 0) begin
            `uvm_error("SB_WRITE", "AXI write completed without a recorded UCIe write request")
          end else begin
            flit = write_req_q.pop_front();
            if (flit[123:120] !== tr.id)
              `uvm_error("SB_WRITE", "write ID packetization mismatch")
            if (flit[119:88] !== tr.addr)
              `uvm_error("SB_WRITE", "write address packetization mismatch")
            if (flit[87:56] !== tr.data)
              `uvm_error("SB_WRITE", "write data packetization mismatch")
            if (flit[55:52] !== tr.strb)
              `uvm_error("SB_WRITE", "write strobe packetization mismatch")
            if (flit[51:44] !== 8'd0 || flit[43:41] !== 3'd2 ||
                flit[40:39] !== 2'b01 || flit[38] !== 1'b1)
              `uvm_error("SB_WRITE", "single-beat AXI metadata packetization mismatch")
          end
          if (tr.resp !== exp_resp)
            `uvm_error("SB_WRITE",
              $sformatf("BRESP %0b expected %0b for addr 0x%08h",
                        tr.resp, exp_resp, tr.addr))
        end else begin
          if (read_req_q.size() == 0) begin
            `uvm_error("SB_READ", "AXI read completed without a recorded UCIe read request")
          end else begin
            flit = read_req_q.pop_front();
            if (flit[123:120] !== tr.id)
              `uvm_error("SB_READ", "read ID packetization mismatch")
            if (flit[119:88] !== tr.addr)
              `uvm_error("SB_READ", "read address packetization mismatch")
            if (flit[51:44] !== 8'd0 || flit[43:41] !== 3'd2 ||
                flit[40:39] !== 2'b01)
              `uvm_error("SB_READ", "single-beat AXI metadata packetization mismatch")
          end
          if (tr.resp !== exp_resp)
            `uvm_error("SB_READ",
              $sformatf("RRESP %0b expected %0b for addr 0x%08h",
                        tr.resp, exp_resp, tr.addr))
          if (tr.read_data !== (tr.addr ^ 32'hA5A5_5A5A))
            `uvm_error("SB_READ",
              $sformatf("RDATA 0x%08h expected 0x%08h",
                        tr.read_data, tr.addr ^ 32'hA5A5_5A5A))
        end
      end
    endtask

    task run_phase(uvm_phase phase);
      fork
        consume_ucie();
        consume_axi();
      join
    endtask
  endclass

  class axi_ucie_coverage extends uvm_subscriber #(axi_txn);
    `uvm_component_utils(axi_ucie_coverage)

    axi_kind_e kind_s;
    bit [1:0] resp_s;
    bit [3:0] region_s;
    bit aw_first_s;

    covergroup cg;
      option.per_instance = 1;
      cp_kind: coverpoint kind_s {
        bins read = {AXI_READ};
        bins write = {AXI_WRITE};
      }
      cp_resp: coverpoint resp_s {
        bins okay = {2'b00};
        bins slverr = {2'b10};
        bins other = default;
      }
      cp_region: coverpoint region_s {
        bins normal[] = {[4'h0:4'hE]};
        bins error_region = {4'hF};
      }
      cp_aw_order: coverpoint aw_first_s iff (kind_s == AXI_WRITE) {
        bins aw_before_w = {1'b1};
        bins w_before_aw = {1'b0};
      }
      kind_x_resp: cross cp_kind, cp_resp;
      kind_x_region: cross cp_kind, cp_region;
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      cg = new();
    endfunction

    virtual function void write(axi_txn t);
      kind_s = t.kind;
      resp_s = t.resp;
      region_s = t.addr[31:28];
      aw_first_s = t.aw_first;
      cg.sample();
    endfunction
  endclass

  class axi_agent extends uvm_component;
    `uvm_component_utils(axi_agent)

    axi_sequencer seqr;
    axi_driver drv;
    axi_monitor mon;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      seqr = axi_sequencer::type_id::create("seqr", this);
      drv = axi_driver::type_id::create("drv", this);
      mon = axi_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
  endclass

  class axi_ucie_env extends uvm_env;
    `uvm_component_utils(axi_ucie_env)

    axi_agent axi;
    ucie_monitor ucie_mon;
    axi_ucie_scoreboard sb;
    axi_ucie_coverage cov;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      axi = axi_agent::type_id::create("axi", this);
      ucie_mon = ucie_monitor::type_id::create("ucie_mon", this);
      sb = axi_ucie_scoreboard::type_id::create("sb", this);
      cov = axi_ucie_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      axi.mon.ap.connect(sb.axi_fifo.analysis_export);
      axi.mon.ap.connect(cov.analysis_export);
      ucie_mon.ap.connect(sb.ucie_fifo.analysis_export);
    endfunction
  endclass

  class axi_smoke_seq extends uvm_sequence #(axi_txn);
    `uvm_object_utils(axi_smoke_seq)

    function new(string name = "axi_smoke_seq");
      super.new(name);
    endfunction

    task body();
      axi_txn tr;
      for (int i = 0; i < 32; i++) begin
        tr = axi_txn::type_id::create($sformatf("tr_%0d", i));
        start_item(tr);
        if (!tr.randomize())
          `uvm_fatal("RAND", "axi_txn randomization failed")
        tr.kind = (i[0]) ? AXI_WRITE : AXI_READ;
        tr.aw_first = i[1];
        tr.resp_backpressure = (i % 5 == 0);
        if (i % 7 == 0)
          tr.addr[31:28] = 4'hF;
        else if (tr.addr[31:28] == 4'hF)
          tr.addr[31:28] = 4'hE;
        finish_item(tr);
      end
    endtask
  endclass

  class axi_cov_guided_seq extends uvm_sequence #(axi_txn);
    `uvm_object_utils(axi_cov_guided_seq)

    int bias_read = 10;
    int bias_write = 10;
    int bias_error_addr = 3;
    int bias_backpressure = 3;
    int bias_aw_first = 10;
    int bias_w_first = 10;

    function new(string name = "axi_cov_guided_seq");
      super.new(name);
    endfunction

    task body();
      axi_txn tr;
      int total;
      int pick;

      void'($value$plusargs("BIAS_READ=%d", bias_read));
      void'($value$plusargs("BIAS_WRITE=%d", bias_write));
      void'($value$plusargs("BIAS_ERROR_ADDR=%d", bias_error_addr));
      void'($value$plusargs("BIAS_BACKPRESSURE=%d", bias_backpressure));
      void'($value$plusargs("BIAS_AW_FIRST=%d", bias_aw_first));
      void'($value$plusargs("BIAS_W_FIRST=%d", bias_w_first));

      for (int i = 0; i < 100; i++) begin
        tr = axi_txn::type_id::create($sformatf("guided_%0d", i));
        start_item(tr);
        if (!tr.randomize())
          `uvm_fatal("RAND", "axi_txn randomization failed")

        total = bias_read + bias_write;
        pick = $urandom_range(1, total);
        tr.kind = (pick <= bias_read) ? AXI_READ : AXI_WRITE;

        total = bias_aw_first + bias_w_first;
        pick = $urandom_range(1, total);
        tr.aw_first = (pick <= bias_aw_first);

        tr.resp_backpressure =
          ($urandom_range(1, 100) <= ((bias_backpressure * 100) /
            (bias_backpressure + 20)));

        if ($urandom_range(1, 100) <= ((bias_error_addr * 100) /
            (bias_error_addr + 20)))
          tr.addr[31:28] = 4'hF;
        else if (tr.addr[31:28] == 4'hF)
          tr.addr[31:28] = $urandom_range(0, 14);

        finish_item(tr);
      end
    endtask
  endclass

  class axi_ucie_base_test extends uvm_test;
    `uvm_component_utils(axi_ucie_base_test)
    axi_ucie_env env;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = axi_ucie_env::type_id::create("env", this);
    endfunction
  endclass

  class axi_ucie_smoke_test extends axi_ucie_base_test;
    `uvm_component_utils(axi_ucie_smoke_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      axi_smoke_seq seq;
      phase.raise_objection(this);
      seq = axi_smoke_seq::type_id::create("seq");
      seq.start(env.axi.seqr);
      repeat (10) @(posedge env.axi.drv.vif.aclk);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_ucie_cov_guided_test extends axi_ucie_base_test;
    `uvm_component_utils(axi_ucie_cov_guided_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      axi_cov_guided_seq seq;
      phase.raise_objection(this);
      seq = axi_cov_guided_seq::type_id::create("seq");
      seq.start(env.axi.seqr);
      repeat (10) @(posedge env.axi.drv.vif.aclk);
      phase.drop_objection(this);
    endtask
  endclass

endpackage
