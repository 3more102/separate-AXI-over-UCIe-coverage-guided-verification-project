# Separate AXI-over-UCIe Coverage-Guided Verification

SystemVerilog and Python verification project for an AXI transaction path
transported over a simplified UCIe-style ready/valid link abstraction.

The UCIe side is intentionally a verification abstraction, not a claim of full
UCIe PHY/Adapter compliance.

## What is implemented

- Single-beat AXI read/write bridge with independent AW/W buffering.
- UCIe-style request/response transport and memory endpoint.
- AXI/link backpressure, AW/W ordering, partial-write, rejected-burst draining, and reset-recovery smoke testing.
- Local SLVERR for unsupported multi-beat requests.
- AXI ready/valid stability assertions.
- Deterministic abstract transport model with retry/error scenarios.
- Coverage-guided UCB1 planner.
- Paired baseline-vs-guided multi-seed experiment harness.
- Coverage-hole to next-run plusarg bias helper.
- Portable UVM per-bin JSON export with an automatic two-pass feedback/rerun target.
- UVM methodology layer with AXI driver/sequencer, source/destination monitors, end-to-end semantic scoreboard, covergroups, and a coverage-guided sequence.
- Python unit tests, Icarus packet smoke/lint, Verilator burst-reference smoke, and GitHub Actions CI.

## Repository layout

    rtl/                 Reference RTL transport path
    tb/interfaces/       AXI interface
    tb/assertions/       Protocol SVA
    tb/models/           Testbench models
    tb/smoke/            Open-source executable smoke test
    tb/axi_ucie_tb_pkg.sv UVM components, sequences, scoreboard, coverage
    tb/tb_top.sv          UVM top using a burst-capable channel tunnel
    python/cgverif/      Abstract model and coverage-guided planner
    tests/               Python unit tests
    examples/            Example coverage input
    scripts/             Coverage feedback helper
    sim/                 Build targets and file lists
    docs/                Verification plan and experiment notes
    .github/workflows/   Continuous integration

## Quick start

Open-source RTL checks:

    make -C sim lint
    make -C sim smoke
    make -C sim reference-smoke

Python tests:

    PYTHONPATH=python python3 -m unittest discover -s tests -p "test_*.py"

Coverage-guided abstract regression:

    PYTHONPATH=python python3 -m cgverif.regress \
      --mode guided --iterations 32 --transactions 16 --seed 1 \
      --out build/guided_regression.json

Paired baseline-vs-guided experiment:

    PYTHONPATH=python python3 -m cgverif.experiment \
      --runs 20 --iterations 32 --transactions 16 --seed 1 \
      --out build/experiment.json

Coverage feedback:

    python3 scripts/coverage_feedback.py \
      --input examples/coverage.sample.json \
      --output build/next_bias.json

Run the complete local open-source verification set with:

    make -C sim all

Optional Questa/UVM smoke:

    make -C sim questa UVM_TEST=axi_ucie_smoke_test UVM_SEED=1

Coverage-guided UVM run, after choosing bias knobs:

    make -C sim questa-guided UVM_SEED=42 UVM_PLUSARGS="+BIAS_LONG=1 +BIAS_FIXED=1"

Automatic two-pass UVM coverage feedback (Questa required):

    make -C sim questa-loop UVM_SEED=42 UVM_TXN_COUNT=100

The first pass writes `build/uvm_coverage.json`, the feedback helper creates
`build/next_bias.json`, and a second guided run is launched only when mapped
coverage holes remain, including the partial-write bin.

## Current boundary

The packetized AXI-to-link RTL milestone still supports one AXI data beat per request. A separate UVM reference tunnel now exercises multi-beat AXI channel transport and end-to-end scoreboarding, but it is a methodology model rather than the packetized UCIe bridge. The portable UVM JSON export mirrors selected named coverpoint bins for feedback and is not a UCDB/native simulator coverage database. Multiple outstanding transactions, out-of-order completion, detailed UCIe retry/CRC behavior, and native coverage merging remain future RTL/UVM integration work. The abstract Python model already exercises credit stalls, CRC retry, timeout retry, reset recovery, and coverage-guided scenario selection.

See docs/VERIFICATION_PLAN.md for the implementation matrix and next steps.
See docs/EXPERIMENT.md for the paired experiment methodology and interpretation limits.
