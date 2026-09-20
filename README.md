# Separate AXI-over-UCIe Coverage-Guided Verification

SystemVerilog and Python verification project for an AXI transaction path
transported over a simplified UCIe-style ready/valid link abstraction.

The UCIe side is intentionally a verification abstraction, not a claim of full
UCIe PHY/Adapter compliance.

## What is implemented

- Single-outstanding AXI read/write bridge with independent AW/W buffering.
- Per-beat packetization of AXI FIXED and INCR bursts onto the UCIe-style request/response link.
- Byte-addressable link-side memory endpoint with write-strobe handling.
- AXI/link backpressure scenarios and reset recovery smoke testing.
- Local SLVERR for unsupported WRAP/reserved burst types and oversized transfer sizes.
- AXI ready/valid stability assertions.
- Deterministic abstract transport model with retry/error scenarios.
- Coverage-guided UCB1 planner.
- Paired baseline-vs-guided multi-seed experiment harness.
- Coverage-hole to next-run plusarg bias helper.
- UVM methodology layer with AXI driver/sequencer, source/destination monitors, end-to-end semantic scoreboard, covergroups, and a coverage-guided sequence.
- Python unit tests, Icarus smoke/lint, and GitHub Actions CI.

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

## Packetized RTL behavior

The packetized bridge supports FIXED and INCR AXI bursts. It serializes each AXI
beat into one link request and waits for the corresponding link response before
advancing that transaction. A write burst produces one AXI B response after the
final beat; a read burst produces one AXI R response per beat with RLAST on the
final response. The current implementation intentionally keeps only one link
request in flight at a time.

WRAP and reserved burst types are rejected locally with SLVERR. The open-source
smoke test covers multi-beat INCR and FIXED traffic, request stalls, AXI response
backpressure, local rejection, and reset recovery.

## Current boundary

The packetized RTL now supports single-outstanding FIXED and INCR bursts, but it
does not yet implement WRAP addressing, multiple outstanding transactions, or
out-of-order completion. The UVM environment still uses a separate burst-capable
channel tunnel for methodology development rather than the packetized bridge
itself. Detailed UCIe retry/CRC behavior remains in the abstract Python model
until a dedicated link agent/fault-injection layer is connected to the RTL path.

See docs/VERIFICATION_PLAN.md for the implementation matrix and next steps.
See docs/EXPERIMENT.md for the paired experiment methodology and interpretation limits.
