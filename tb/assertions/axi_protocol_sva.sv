module axi_protocol_sva (
  axi_if axi,
  ucie_link_if link
);

  property p_aw_stable_while_stalled;
    @(posedge axi.aclk) disable iff (!axi.aresetn)
      axi.awvalid && !axi.awready |=> axi.awvalid &&
      $stable({axi.awid, axi.awaddr, axi.awlen, axi.awsize, axi.awburst});
  endproperty
  assert property (p_aw_stable_while_stalled);

  property p_w_stable_while_stalled;
    @(posedge axi.aclk) disable iff (!axi.aresetn)
      axi.wvalid && !axi.wready |=> axi.wvalid &&
      $stable({axi.wdata, axi.wstrb, axi.wlast});
  endproperty
  assert property (p_w_stable_while_stalled);

  property p_ar_stable_while_stalled;
    @(posedge axi.aclk) disable iff (!axi.aresetn)
      axi.arvalid && !axi.arready |=> axi.arvalid &&
      $stable({axi.arid, axi.araddr, axi.arlen, axi.arsize, axi.arburst});
  endproperty
  assert property (p_ar_stable_while_stalled);

  property p_b_stable_while_stalled;
    @(posedge axi.aclk) disable iff (!axi.aresetn)
      axi.bvalid && !axi.bready |=> axi.bvalid &&
      $stable({axi.bid, axi.bresp});
  endproperty
  assert property (p_b_stable_while_stalled);

  property p_r_stable_while_stalled;
    @(posedge axi.aclk) disable iff (!axi.aresetn)
      axi.rvalid && !axi.rready |=> axi.rvalid &&
      $stable({axi.rid, axi.rdata, axi.rresp, axi.rlast});
  endproperty
  assert property (p_r_stable_while_stalled);

  property p_ucie_tx_stable_while_stalled;
    @(posedge link.clk) disable iff (!link.rst_n)
      link.tx_valid && !link.tx_ready |=> link.tx_valid &&
      $stable(link.tx_data);
  endproperty
  assert property (p_ucie_tx_stable_while_stalled);

  cover property (@(posedge link.clk) disable iff (!link.rst_n)
    link.tx_valid && !link.tx_ready);

  cover property (@(posedge axi.aclk) disable iff (!axi.aresetn)
    axi.rvalid && !axi.rready);

  cover property (@(posedge axi.aclk) disable iff (!axi.aresetn)
    axi.bvalid && !axi.bready);

endmodule
