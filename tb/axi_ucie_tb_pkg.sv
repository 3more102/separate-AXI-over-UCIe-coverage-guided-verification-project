package axi_ucie_tb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  parameter int AXI_ID_W   = 4;
  parameter int AXI_ADDR_W = 32;
  parameter int AXI_DATA_W = 32;
  parameter int AXI_STRB_W = AXI_DATA_W/8;

  typedef virtual axi_if #(AXI_ID_W, AXI_ADDR_W, AXI_DATA_W) axi_vif_t;

  typedef enum bit {AXI_READ, AXI_WRITE} axi_kind_e;

  class axi_txn extends uvm_sequence_item;
    rand axi_kind_e kind;
    rand bit [AXI_ID_W-1:0] id;
    rand bit [AXI_ADDR_W-1:0] addr;
    rand bit [7:0] len;
    rand bit [2:0] size;
    rand bit [1:0] burst;
    rand bit [AXI_DATA_W-1:0] data_q[$];
    rand bit [AXI_STRB_W-1:0] strb_q[$];
         bit [1:0] resp_q[$];

    constraint c_len   { len inside {[0:15]}; }
    constraint c_size  { size inside {[0:2]}; }
    constraint c_burst { burst inside {2'b00, 2'b01}; }
    constraint c_addr  {
      addr inside {[0:3840]};
      (addr & ((1 << size)-1)) == 0;
    }
    constraint c_payload {
      if (kind == AXI_WRITE) {
        data_q.size() == len + 1;
        strb_q.size() == len + 1;
        foreach (strb_q[i]) strb_q[i] == '1;
      } else {
        data_q.size() == 0;
        strb_q.size() == 0;
      }
    }

    `uvm_object_utils_begin(axi_txn)
      `uvm_field_enum(axi_kind_e, kind, UVM_ALL_ON)
      `uvm_field_int(id, UVM_ALL_ON)
      `uvm_field_int(addr, UVM_ALL_ON)
      `uvm_field_int(len, UVM_ALL_ON)
      `uvm_field_int(size, UVM_ALL_ON)
      `uvm_field_int(burst, UVM_ALL_ON)
      `uvm_field_queue_int(data_q, UVM_ALL_ON)
      `uvm_field_queue_int(strb_q, UVM_ALL_ON)
      `uvm_field_queue_int(resp_q, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name="axi_txn");
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

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(axi_vif_t)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "axi_driver requires vif")
    endfunction

    task reset_signals();
      vif.awvalid <= 1'b0;
      vif.wvalid  <= 1'b0;
      vif.bready  <= 1'b0;
      vif.arvalid <= 1'b0;
      vif.rready  <= 1'b0;
    endtask

    task drive_write(axi_txn tr);
      int i;
      @(posedge vif.aclk);
      vif.awid    <= tr.id;
      vif.awaddr  <= tr.addr;
      vif.awlen   <= tr.len;
      vif.awsize  <= tr.size;
      vif.awburst <= tr.burst;
      vif.awvalid <= 1'b1;
      do @(posedge vif.aclk); while (!vif.awready);
      vif.awvalid <= 1'b0;

      for (i = 0; i < tr.data_q.size(); i++) begin
        vif.wdata  <= tr.data_q[i];
        vif.wstrb  <= tr.strb_q[i];
        vif.wlast  <= (i == tr.data_q.size()-1);
        vif.wvalid <= 1'b1;
        do @(posedge vif.aclk); while (!vif.wready);
        vif.wvalid <= 1'b0;
      end

      vif.bready <= 1'b1;
      do @(posedge vif.aclk); while (!vif.bvalid);
      if (vif.bresp != 2'b00)
        `uvm_warning("BRESP", $sformatf("Non-OKAY BRESP=%0b id=%0h", vif.bresp, vif.bid))
      @(posedge vif.aclk);
      vif.bready <= 1'b0;
    endtask

    task drive_read(axi_txn tr);
      int beats;
      int i;
      beats = tr.len + 1;

      @(posedge vif.aclk);
      vif.arid    <= tr.id;
      vif.araddr  <= tr.addr;
      vif.arlen   <= tr.len;
      vif.arsize  <= tr.size;
      vif.arburst <= tr.burst;
      vif.arvalid <= 1'b1;
      do @(posedge vif.aclk); while (!vif.arready);
      vif.arvalid <= 1'b0;

      vif.rready <= 1'b1;
      for (i = 0; i < beats; i++) begin
        do @(posedge vif.aclk); while (!vif.rvalid);
        if (vif.rlast !== (i == beats-1))
          `uvm_error("RLAST", $sformatf("Unexpected RLAST at beat %0d/%0d", i, beats))
      end
      @(posedge vif.aclk);
      vif.rready <= 1'b0;
    endtask

    task run_phase(uvm_phase phase);
      axi_txn tr;
      reset_signals();
      wait (vif.aresetn === 1'b1);
      forever begin
        seq_item_port.get_next_item(tr);
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

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(axi_vif_t)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "axi_monitor requires vif")
    endfunction

    task monitor_writes();
      axi_txn tr;
      forever begin
        do @(posedge vif.aclk); while (!(vif.awvalid && vif.awready));
        tr = axi_txn::type_id::create("mon_write");
        tr.kind  = AXI_WRITE;
        tr.id    = vif.awid;
        tr.addr  = vif.awaddr;
        tr.len   = vif.awlen;
        tr.size  = vif.awsize;
        tr.burst = vif.awburst;

        forever begin
          do @(posedge vif.aclk); while (!(vif.wvalid && vif.wready));
          tr.data_q.push_back(vif.wdata);
          tr.strb_q.push_back(vif.wstrb);
          if (vif.wlast)
            break;
        end

        do @(posedge vif.aclk); while (!(vif.bvalid && vif.bready));
        tr.resp_q.push_back(vif.bresp);
        ap.write(tr);
      end
    endtask

    task monitor_reads();
      axi_txn tr;
      forever begin
        do @(posedge vif.aclk); while (!(vif.arvalid && vif.arready));
        tr = axi_txn::type_id::create("mon_read");
        tr.kind  = AXI_READ;
        tr.id    = vif.arid;
        tr.addr  = vif.araddr;
        tr.len   = vif.arlen;
        tr.size  = vif.arsize;
        tr.burst = vif.arburst;

        forever begin
          do @(posedge vif.aclk); while (!(vif.rvalid && vif.rready));
          tr.data_q.push_back(vif.rdata);
          tr.resp_q.push_back(vif.rresp);
          if (vif.rlast)
            break;
        end
        ap.write(tr);
      end
    endtask

    task run_phase(uvm_phase phase);
      wait (vif.aresetn === 1'b1);
      fork
        monitor_writes();
        monitor_reads();
      join
    endtask
  endclass

  class axi_scoreboard extends uvm_component;
    `uvm_component_utils(axi_scoreboard)
    uvm_tlm_analysis_fifo #(axi_txn) src_fifo;
    uvm_tlm_analysis_fifo #(axi_txn) dst_fifo;
    int unsigned compared;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      src_fifo = new("src_fifo", this);
      dst_fifo = new("dst_fifo", this);
      compared = 0;
    endfunction

    function bit equivalent(axi_txn a, axi_txn b);
      if (a.kind != b.kind || a.id != b.id || a.addr != b.addr ||
          a.len != b.len || a.size != b.size || a.burst != b.burst)
        return 0;
      if (a.data_q.size() != b.data_q.size() ||
          a.strb_q.size() != b.strb_q.size() ||
          a.resp_q.size() != b.resp_q.size())
        return 0;
      foreach (a.data_q[i])
        if (a.data_q[i] !== b.data_q[i]) return 0;
      foreach (a.strb_q[i])
        if (a.strb_q[i] !== b.strb_q[i]) return 0;
      foreach (a.resp_q[i])
        if (a.resp_q[i] !== b.resp_q[i]) return 0;
      return 1;
    endfunction

    task run_phase(uvm_phase phase);
      axi_txn src;
      axi_txn dst;
      forever begin
        src_fifo.get(src);
        dst_fifo.get(dst);
        if (!equivalent(src, dst)) begin
          `uvm_error("E2E_MISMATCH",
            $sformatf("Source and destination transactions differ\nSRC:\n%s\nDST:\n%s",
                      src.sprint(), dst.sprint()))
        end else begin
          compared++;
          `uvm_info("E2E_MATCH",
            $sformatf("Matched transaction %0d kind=%s id=%0h len=%0d",
                      compared, src.kind.name(), src.id, src.len), UVM_MEDIUM)
        end
      end
    endtask
  endclass

  class axi_coverage extends uvm_subscriber #(axi_txn);
    `uvm_component_utils(axi_coverage)
    axi_kind_e sample_kind;
    bit [7:0] sample_len;
    bit [1:0] sample_burst;
    bit [2:0] sample_size;

    covergroup cg;
      option.per_instance = 1;
      cp_kind: coverpoint sample_kind {
        bins read  = {AXI_READ};
        bins write = {AXI_WRITE};
      }
      cp_len: coverpoint sample_len {
        bins single = {0};
        bins short  = {[1:3]};
        bins medium = {[4:7]};
        bins long   = {[8:15]};
      }
      cp_burst: coverpoint sample_burst {
        bins fixed = {2'b00};
        bins incr  = {2'b01};
      }
      cp_size: coverpoint sample_size {
        bins byte = {0};
        bins half = {1};
        bins word = {2};
      }
      kind_x_len_x_burst: cross cp_kind, cp_len, cp_burst;
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      cg = new();
    endfunction

    function void write(axi_txn t);
      sample_kind  = t.kind;
      sample_len   = t.len;
      sample_burst = t.burst;
      sample_size  = t.size;
      cg.sample();
    endfunction
  endclass

  class axi_ucie_env extends uvm_env;
    `uvm_component_utils(axi_ucie_env)
    axi_sequencer seqr;
    axi_driver drv;
    axi_monitor src_mon;
    axi_monitor dst_mon;
    axi_scoreboard sb;
    axi_coverage cov;
    axi_vif_t src_vif;
    axi_vif_t dst_vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(axi_vif_t)::get(this, "", "src_vif", src_vif))
        `uvm_fatal("NOVIF", "env requires src_vif")
      if (!uvm_config_db#(axi_vif_t)::get(this, "", "dst_vif", dst_vif))
        `uvm_fatal("NOVIF", "env requires dst_vif")

      uvm_config_db#(axi_vif_t)::set(this, "drv",     "vif", src_vif);
      uvm_config_db#(axi_vif_t)::set(this, "src_mon", "vif", src_vif);
      uvm_config_db#(axi_vif_t)::set(this, "dst_mon", "vif", dst_vif);

      seqr    = axi_sequencer::type_id::create("seqr", this);
      drv     = axi_driver::type_id::create("drv", this);
      src_mon = axi_monitor::type_id::create("src_mon", this);
      dst_mon = axi_monitor::type_id::create("dst_mon", this);
      sb      = axi_scoreboard::type_id::create("sb", this);
      cov     = axi_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      drv.seq_item_port.connect(seqr.seq_item_export);
      src_mon.ap.connect(sb.src_fifo.analysis_export);
      dst_mon.ap.connect(sb.dst_fifo.analysis_export);
      src_mon.ap.connect(cov.analysis_export);
    endfunction
  endclass

  class axi_smoke_seq extends uvm_sequence #(axi_txn);
    `uvm_object_utils(axi_smoke_seq)
    function new(string name="axi_smoke_seq");
      super.new(name);
    endfunction

    task body();
      axi_txn tr;
      int i;
      for (i = 0; i < 12; i++) begin
        tr = axi_txn::type_id::create($sformatf("tr_%0d", i));
        start_item(tr);
        if (!tr.randomize() with {
          kind == ((i % 2) ? AXI_READ : AXI_WRITE);
          if ((i % 3) == 0) len == 0;
          else len inside {[1:7]};
        })
          `uvm_fatal("RAND", "axi_smoke_seq randomization failed")
        finish_item(tr);
      end
    endtask
  endclass

  class axi_cov_guided_seq extends uvm_sequence #(axi_txn);
    `uvm_object_utils(axi_cov_guided_seq)
    function new(string name="axi_cov_guided_seq");
      super.new(name);
    endfunction

    task body();
      axi_txn tr;
      int count = 100;
      bit bias_long, bias_medium, bias_fixed, bias_incr, bias_read, bias_write;
      int tmp;

      void'($value$plusargs("TXN_COUNT=%d", count));
      bias_long   = $value$plusargs("BIAS_LONG=%d", tmp)   && (tmp != 0);
      tmp = 0;
      bias_medium = $value$plusargs("BIAS_MEDIUM=%d", tmp) && (tmp != 0);
      tmp = 0;
      bias_fixed  = $value$plusargs("BIAS_FIXED=%d", tmp)  && (tmp != 0);
      tmp = 0;
      bias_incr   = $value$plusargs("BIAS_INCR=%d", tmp)   && (tmp != 0);
      tmp = 0;
      bias_read   = $value$plusargs("BIAS_READ=%d", tmp)   && (tmp != 0);
      tmp = 0;
      bias_write  = $value$plusargs("BIAS_WRITE=%d", tmp)  && (tmp != 0);

      repeat (count) begin
        tr = axi_txn::type_id::create("cov_tr");
        start_item(tr);
        if (!tr.randomize() with {
          if (bias_long) len inside {[8:15]};
          else if (bias_medium) len inside {[4:7]};
          if (bias_fixed && !bias_incr) burst == 2'b00;
          if (bias_incr && !bias_fixed) burst == 2'b01;
          if (bias_read && !bias_write) kind == AXI_READ;
          if (bias_write && !bias_read) kind == AXI_WRITE;
        })
          `uvm_fatal("RAND", "axi_cov_guided_seq randomization failed")
        finish_item(tr);
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
      axi_smoke_seq seq = axi_smoke_seq::type_id::create("seq");
      phase.raise_objection(this);
      phase.phase_done.set_drain_time(this, 100ns);
      seq.start(env.seqr);
      phase.drop_objection(this);
    endtask
  endclass

  class axi_ucie_cov_guided_test extends uvm_test;
    `uvm_component_utils(axi_ucie_cov_guided_test)
    axi_ucie_env env;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = axi_ucie_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
      axi_cov_guided_seq seq = axi_cov_guided_seq::type_id::create("seq");
      phase.raise_objection(this);
      phase.phase_done.set_drain_time(this, 100ns);
      seq.start(env.seqr);
      phase.drop_objection(this);
    endtask
  endclass
endpackage
