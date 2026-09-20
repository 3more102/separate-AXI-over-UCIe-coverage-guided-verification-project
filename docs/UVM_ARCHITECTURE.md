# UVM Architecture

## Purpose

The UVM layer is a methodology harness for end-to-end AXI semantic checking and functional coverage. It is intentionally separate from the executable packetized RTL milestone.

## Data path

The current UVM top uses:

    source AXI driver
        -> burst-capable ready/valid reference tunnel
        -> destination AXI memory model

The source and destination interfaces are both monitored. Completed transactions are reconstructed independently and pushed into two analysis FIFOs. The scoreboard compares the two streams transaction-by-transaction.

This makes transport latency and backpressure non-golden: only end-to-end AXI semantics are checked.

## Components

- axi_txn: read/write item with ID, address, LEN, SIZE, BURST, data/strobes, and responses.
- axi_driver: sequential read/write AXI master driver.
- axi_monitor: reconstructs completed write and read transactions.
- axi_scoreboard: compares source-side and destination-side semantics.
- axi_coverage: samples operation, burst length class, burst type, narrow/full-width size, full-vs-partial WSTRB relative to the legal transfer mask, and a key cross.
- axi_smoke_seq: small mixed read/write sequence.
- axi_cov_guided_seq: larger sequence accepting next-run bias plusargs.

## Coverage-guidance knobs

The sequence recognizes:

- +BIAS_LONG=1
- +BIAS_MEDIUM=1
- +BIAS_FIXED=1
- +BIAS_INCR=1
- +BIAS_READ=1
- +BIAS_WRITE=1
- +BIAS_PARTIAL=1
- +BIAS_NARROW=1
- +BIAS_FULL=1
- +TXN_COUNT=N

The helper in scripts/coverage_feedback.py converts neutral JSON bin counts into these plusargs, including `strobe.partial`, `size.narrow`, and `size.full`. Narrow transfers use address-relative legal byte lanes; partial-write classification compares WSTRB with that legal mask instead of bus-wide all-ones.

## Important boundary

rtl/axi_ucie_bridge.sv is the packetized AXI-to-UCIe-style executable DUT and currently accepts single-beat requests.

rtl/axi_ucie_reference_dut.sv is a separate burst-capable channel-tunnel reference model used by the UVM environment. Passing the UVM reference-tunnel tests therefore does not prove that the packetized RTL supports multi-beat bursts.

The next integration step is to replace the reference tunnel with the packetized bridge plus a dedicated link agent/endpoint while retaining the same monitor, scoreboard, and coverage policy.
