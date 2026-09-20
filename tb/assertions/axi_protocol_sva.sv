module axi_protocol_sva (
  axi_if.monitor axi
);
  property p_aw_stable_until_ready;
    @(posedge axi.aclk) disable iff (!axi.aresetn)
      axi.awvalid && !axi.awready |=> axi.awvalid &&
        $stable({axi.awid, axi.awaddr, axi.awlen, axi.awsize, axi.awburst});
  endproperty

  property p_w_stable_until_ready;
    @(posedge axi.aclk) disable iff (!axi.aresetn)
      axi.wvalid && !axi.wready |=> axi.wvalid &&
        $stable({axi.wdata, axi.wstrb, axi.wlast});
  endproperty

  property p_ar_stable_until_ready;
    @(posedge axi.aclk) disable iff (!axi.aresetn)
      axi.arvalid && !axi.arready |=> axi.arvalid &&
        $stable({axi.arid, axi.araddr, axi.arlen, axi.arsize, axi.arburst});
  endproperty

  property p_b_stable_until_ready;
    @(posedge axi.aclk) disable iff (!axi.aresetn)
      axi.bvalid && !axi.bready |=> axi.bvalid &&
        $stable({axi.bid, axi.bresp});
  endproperty

  property p_r_stable_until_ready;
    @(posedge axi.aclk) disable iff (!axi.aresetn)
      axi.rvalid && !axi.rready |=> axi.rvalid &&
        $stable({axi.rid, axi.rdata, axi.rresp, axi.rlast});
  endproperty

  a_aw_stable_until_ready: assert property (p_aw_stable_until_ready);
  a_w_stable_until_ready : assert property (p_w_stable_until_ready);
  a_ar_stable_until_ready: assert property (p_ar_stable_until_ready);
  a_b_stable_until_ready : assert property (p_b_stable_until_ready);
  a_r_stable_until_ready : assert property (p_r_stable_until_ready);
endmodule
