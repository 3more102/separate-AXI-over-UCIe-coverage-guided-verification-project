package axi_ucie_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  localparam int AXI_ID_W   = 4;
  localparam int AXI_ADDR_W = 32;
  localparam int AXI_DATA_W = 64;

  typedef virtual axi_if #(AXI_ID_W, AXI_ADDR_W, AXI_DATA_W) axi_vif_t;

  typedef enum bit {AXI_READ, AXI_WRITE} axi_kind_e;

  class axi_txn extends uvm_sequence_item;
    rand axi_kind_e              kind;
    rand bit [AXI_ID_W-1:0]      id;
    rand bit [AXI_ADDR_W-1:0]    addr;
    rand bit [7:0]               len;
    rand bit [2:0]               size;
    rand bit [1:0]               burst;
    rand bit [AXI_DATA_W-1:0]    wdata;
    rand bit [AXI_DATA_W/8-1:0]  wstrb;

    bit [1:0]                    resp;
    bit [AXI_DATA_W-1:0]         rdata;

    constraint c_milestone1 {
      len == 8'd0;
      size == 3'd3;
      burst == 2'b01;
      addr[2:0] == 3'b000;
      if (kind == AXI_WRITE) wstrb != '0;
    }

    `uvm_object_utils_begin(axi_txn)
      `uvm_field_enum(axi_kind_e, kind, UVM_ALL_ON)
      `uvm_field_int(id, UVM_ALL_ON)
      `uvm_field_int(addr, UVM_ALL_ON)
      `uvm_field_int(len, UVM_ALL_ON)
      `uvm_field_int(size, UVM_ALL_ON)
      `uvm_field_int(burst, UVM_ALL_ON)
      `uvm_field_int(wdata, UVM_ALL_ON)
      `uvm_field_int(wstrb, UVM_ALL_ON)
      `uvm_field_int(resp, UVM_ALL_ON)
      `uvm_field_int(rdata, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "axi_txn");
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

    axi_vif_t vif;
    uvm_analysis_port #(axi_txn) expected_ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      expected_ap = new("expected_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(axi_vif_t)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "axi_driver requires virtual axi_if")
    endfunction

    task reset_outputs();
      vif.awvalid <= 1'b0;
      vif.wvalid  <= 1'b0;
      vif.bready  <= 1'b0;
      vif.arvalid <= 1'b0;
      vif.rready  <= 1'b0;
    endtask

    task drive_write(axi_txn tr);
      @(negedge vif.aclk);
      vif.awid    <= tr.id;
      vif.awaddr  <= tr.addr;
      vif.awlen   <= tr.len;
      vif.awsize  <= tr.size;
      vif.awburst <= tr.burst;
      vif.awvalid <= 1'b1;

      vif.wdata   <= tr.wdata;
      vif.wstrb   <= tr.wstrb;
      vif.wlast   <= 1'b1;
      vif.wvalid  <= 1'b1;

      fork
        begin
          do @(posedge vif.aclk); while (!vif.awready);
          @(negedge vif.aclk);
          vif.awvalid <= 1'b0;
        end
        begin
          do @(posedge vif.aclk); while (!vif.wready);
          @(negedge vif.aclk);
          vif.wvalid <= 1'b0;
        end
      join

      @(negedge vif.aclk);
      vif.bready <= 1'b1;
      do @(posedge vif.aclk); while (!vif.bvalid);
      tr.resp = vif.bresp;
      @(negedge vif.aclk);
      vif.bready <= 1'b0;
    endtask

    task drive_read(axi_txn tr);
      @(negedge vif.aclk);
      vif.arid    <= tr.id;
      vif.araddr  <= tr.addr;
      vif.arlen   <= tr.len;
      vif.arsize  <= tr.size;
      vif.arburst <= tr.burst;
      vif.arvalid <= 1'b1;

      do @(posedge vif.aclk); while (!vif.arready);
      @(negedge vif.aclk);
      vif.arvalid <= 1'b0;
      vif.rready  <= 1'b1;

      do @(posedge vif.aclk); while (!vif.rvalid);
      tr.resp  = vif.rresp;
      tr.rdata = vif.rdata;
      if (!vif.rlast)
        `uvm_error("AXI_RLAST", "milestone-1 read completed without RLAST")

      @(negedge vif.aclk);
      vif.rready <= 1'b0;
    endtask

    task run_phase(uvm_phase phase);
      axi_txn tr;
      axi_txn expected;
      reset_outputs();

      forever begin
        seq_item_port.get_next_item(tr);
        wait (vif.aresetn === 1'b1);

        $cast(expected, tr.clone());
        expected_ap.write(expected);

        if (tr.kind == AXI_WRITE)
          drive_write(tr);
        else
          drive_read(tr);

        seq_item_port.item_done();
      end
    endtask
  endclass

  class axi_monitor extends uvm_component;
    `uvm_component_utils(axi_monitor)

    axi_vif_t vif;
    uvm_analysis_port #(axi_txn) ap;

    bit aw_seen;
    bit w_seen;
    bit ar_seen;

    bit [AXI_ID_W-1:0] aw_id_q;
    bit [AXI_ADDR_W-1:0] aw_addr_q;
    bit [7:0] aw_len_q;
    bit [2:0] aw_size_q;
    bit [1:0] aw_burst_q;
    bit [AXI_DATA_W-1:0] w_data_q;
    bit [AXI_DATA_W/8-1:0] w_strb_q;

    bit [AXI_ID_W-1:0] ar_id_q;
    bit [AXI_ADDR_W-1:0] ar_addr_q;
    bit [7:0] ar_len_q;
    bit [2:0] ar_size_q;
    bit [1:0] ar_burst_q;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(axi_vif_t)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "axi_monitor requires virtual axi_if")
    endfunction

    task run_phase(uvm_phase phase);
      axi_txn tr;
      forever begin
        @(posedge vif.aclk);

        if (!vif.aresetn) begin
          aw_seen = 1'b0;
          w_seen  = 1'b0;
          ar_seen = 1'b0;
          continue;
        end

        if (vif.awvalid && vif.awready) begin
          aw_seen    = 1'b1;
          aw_id_q    = vif.awid;
          aw_addr_q  = vif.awaddr;
          aw_len_q   = vif.awlen;
          aw_size_q  = vif.awsize;
          aw_burst_q = vif.awburst;
        end

        if (vif.wvalid && vif.wready) begin
          w_seen   = 1'b1;
          w_data_q = vif.wdata;
          w_strb_q = vif.wstrb;
        end

        if (vif.bvalid && vif.bready) begin
          if (!(aw_seen && w_seen))
            `uvm_error("MON_WRITE", "B response observed without captured AW/W")
          tr = axi_txn::type_id::create("write_tr");
          tr.kind  = AXI_WRITE;
          tr.id    = vif.bid;
          tr.addr  = aw_addr_q;
          tr.len   = aw_len_q;
          tr.size  = aw_size_q;
          tr.burst = aw_burst_q;
          tr.wdata = w_data_q;
          tr.wstrb = w_strb_q;
          tr.resp  = vif.bresp;
          ap.write(tr);
          aw_seen = 1'b0;
          w_seen  = 1'b0;
        end

        if (vif.arvalid && vif.arready) begin
          ar_seen    = 1'b1;
          ar_id_q    = vif.arid;
          ar_addr_q  = vif.araddr;
          ar_len_q   = vif.arlen;
          ar_size_q  = vif.arsize;
          ar_burst_q = vif.arburst;
        end

        if (vif.rvalid && vif.rready) begin
          if (!ar_seen)
            `uvm_error("MON_READ", "R response observed without captured AR")
          tr = axi_txn::type_id::create("read_tr");
          tr.kind  = AXI_READ;
          tr.id    = vif.rid;
          tr.addr  = ar_addr_q;
          tr.len   = ar_len_q;
          tr.size  = ar_size_q;
          tr.burst = ar_burst_q;
          tr.resp  = vif.rresp;
          tr.rdata = vif.rdata;
          ap.write(tr);
          if (vif.rlast)
            ar_seen = 1'b0;
        end
      end
    endtask
  endclass

  class axi_scoreboard extends uvm_component;
    `uvm_component_utils(axi_scoreboard)

    uvm_tlm_analysis_fifo #(axi_txn) expected_fifo;
    uvm_tlm_analysis_fifo #(axi_txn) actual_fifo;
    bit [AXI_DATA_W-1:0] memory [bit [AXI_ADDR_W-1:0]];

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      expected_fifo = new("expected_fifo", this);
      actual_fifo   = new("actual_fifo", this);
    endfunction

    function void apply_write(axi_txn tr);
      bit [AXI_DATA_W-1:0] value;
      value = memory.exists(tr.addr) ? memory[tr.addr] : '0;
      for (int byte_idx = 0; byte_idx < AXI_DATA_W/8; byte_idx++)
        if (tr.wstrb[byte_idx])
          value[8*byte_idx +: 8] = tr.wdata[8*byte_idx +: 8];
      memory[tr.addr] = value;
    endfunction

    task run_phase(uvm_phase phase);
      axi_txn exp;
      axi_txn act;
      forever begin
        expected_fifo.get(exp);
        actual_fifo.get(act);

        if (exp.kind != act.kind)
          `uvm_error("SB_KIND", $sformatf("expected %0d got %0d", exp.kind, act.kind))
        if (exp.id != act.id)
          `uvm_error("SB_ID", $sformatf("expected id %0d got %0d", exp.id, act.id))
        if (exp.addr != act.addr)
          `uvm_error("SB_ADDR", $sformatf("expected addr %h got %h", exp.addr, act.addr))
        if (act.resp != 2'b00)
          `uvm_error("SB_RESP", $sformatf("unexpected AXI response %0b", act.resp))

        if (exp.kind == AXI_WRITE) begin
          if (exp.wdata != act.wdata || exp.wstrb != act.wstrb)
            `uvm_error("SB_WRITE", "write payload differs from driven request")
          apply_write(exp);
        end else if (memory.exists(exp.addr)) begin
          if (act.rdata != memory[exp.addr])
            `uvm_error(
              "SB_RDATA",
              $sformatf("addr=%h expected=%h got=%h",
                        exp.addr, memory[exp.addr], act.rdata)
            )
        end else begin
          `uvm_warning("SB_UNINIT", $sformatf("read from unwritten address %h", exp.addr))
        end
      end
    endtask
  endclass

  class axi_coverage extends uvm_subscriber #(axi_txn);
    `uvm_component_utils(axi_coverage)

    axi_kind_e sample_kind;
    bit [7:0] sample_len;
    bit [1:0] sample_burst;
    bit [1:0] sample_resp;

    covergroup cg;
      option.per_instance = 1;
      cp_kind: coverpoint sample_kind;
      cp_len: coverpoint sample_len {
        bins single = {0};
        bins short_burst = {[1:3]};
        bins medium_burst = {[4:15]};
        bins long_burst = {[16:255]};
      }
      cp_burst: coverpoint sample_burst {
        bins fixed = {2'b00};
        bins incr  = {2'b01};
        bins wrap  = {2'b10};
      }
      cp_resp: coverpoint sample_resp {
        bins okay   = {2'b00};
        bins exokay = {2'b01};
        bins slverr = {2'b10};
        bins decerr = {2'b11};
      }
      kind_x_len: cross cp_kind, cp_len;
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      cg = new();
    endfunction

    function void write(axi_txn t);
      sample_kind  = t.kind;
      sample_len   = t.len;
      sample_burst = t.burst;
      sample_resp  = t.resp;
      cg.sample();
    endfunction
  endclass

  class axi_agent extends uvm_agent;
    `uvm_component_utils(axi_agent)

    axi_sequencer sequencer;
    axi_driver driver;
    axi_monitor monitor;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sequencer = axi_sequencer::type_id::create("sequencer", this);
      driver    = axi_driver::type_id::create("driver", this);
      monitor   = axi_monitor::type_id::create("monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

  class axi_ucie_env extends uvm_env;
    `uvm_component_utils(axi_ucie_env)

    axi_agent agent;
    axi_scoreboard scoreboard;
    axi_coverage coverage;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent      = axi_agent::type_id::create("agent", this);
      scoreboard = axi_scoreboard::type_id::create("scoreboard", this);
      coverage   = axi_coverage::type_id::create("coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      agent.driver.expected_ap.connect(scoreboard.expected_fifo.analysis_export);
      agent.monitor.ap.connect(scoreboard.actual_fifo.analysis_export);
      agent.monitor.ap.connect(coverage.analysis_export);
    endfunction
  endclass

  class axi_ucie_smoke_seq extends uvm_sequence #(axi_txn);
    `uvm_object_utils(axi_ucie_smoke_seq)

    function new(string name = "axi_ucie_smoke_seq");
      super.new(name);
    endfunction

    task body();
      axi_txn wr;
      axi_txn rd;
      bit [AXI_ADDR_W-1:0] saved_addr;
      bit [AXI_ID_W-1:0] saved_id;

      repeat (8) begin
        wr = axi_txn::type_id::create("wr");
        start_item(wr);
        if (!wr.randomize() with { kind == AXI_WRITE; addr inside {[0:1023]}; })
          `uvm_fatal("RAND", "failed to randomize write transaction")
        finish_item(wr);

        saved_addr = wr.addr;
        saved_id   = wr.id;

        rd = axi_txn::type_id::create("rd");
        start_item(rd);
        rd.kind  = AXI_READ;
        rd.id    = saved_id;
        rd.addr  = saved_addr;
        rd.len   = 8'd0;
        rd.size  = 3'd3;
        rd.burst = 2'b01;
        rd.wdata = '0;
        rd.wstrb = '0;
        finish_item(rd);
      end
    endtask
  endclass

  class axi_ucie_smoke_test extends uvm_test;
    `uvm_component_utils(axi_ucie_smoke_test)

    axi_ucie_env env;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = axi_ucie_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
      axi_ucie_smoke_seq seq;
      phase.raise_objection(this);
      seq = axi_ucie_smoke_seq::type_id::create("seq");
      seq.start(env.agent.sequencer);
      phase.drop_objection(this);
    endtask
  endclass

endpackage
