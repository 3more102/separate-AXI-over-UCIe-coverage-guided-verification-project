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
- axi_coverage: samples operation, burst length class, burst type, size, and a key cross.
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
- +TXN_COUNT=N

The helper in scripts/coverage_feedback.py converts neutral JSON bin counts into these plusargs.

The coverage subscriber also keeps explicit hit counters that mirror the named
operation, length, burst, full-width size, and full-vs-partial strobe bins. The
guided test serializes them to `build/uvm_coverage.json` by default; override
the path with `+COVERAGE_JSON=<path>`.

A two-pass feedback run is available with:

    make -C sim questa-loop UVM_SEED=42 UVM_TXN_COUNT=100

The first run exports the counters, `feedback-uvm` maps uncovered bins
(including `strobe.partial`) to bias plusargs, and a second guided run is
launched only when mapped holes remain. These counters are portable feedback
data; they are not simulator-native UCDB coverage and do not yet include cross
bins.

## Important boundary

rtl/axi_ucie_bridge.sv is the packetized AXI-to-UCIe-style executable DUT and currently accepts single-beat requests.

rtl/axi_ucie_reference_dut.sv is a separate burst-capable channel-tunnel reference model used by the UVM environment. Passing the UVM reference-tunnel tests therefore does not prove that the packetized RTL supports multi-beat bursts.

The next integration step is to replace the reference tunnel with the packetized bridge plus a dedicated link agent/endpoint while retaining the same monitor, scoreboard, and coverage policy.
