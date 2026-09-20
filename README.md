# Separate AXI-over-UCIe Coverage-Guided Verification

SystemVerilog and Python verification project for an AXI transaction path
transported over a simplified UCIe-style ready/valid link abstraction.

The UCIe side is intentionally a verification abstraction, not a claim of full
UCIe PHY/Adapter compliance.

## What is implemented

- Single-beat AXI read/write bridge with independent AW/W buffering.
- UCIe-style request/response transport and memory endpoint.
- AXI/link backpressure scenarios and reset recovery smoke testing.
- Local SLVERR for unsupported multi-beat requests.
- AXI ready/valid stability assertions.
- Deterministic abstract transport model with retry/error scenarios.
- Coverage-guided UCB1 planner.
- Per-bin neutral coverage artifacts with hit counts.
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
    docs/                Verification plan
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

The regression JSON includes a neutral `bins` object containing per-bin hit
counts, including explicit zero-hit bins. Feed that artifact directly into the
next-run bias helper:

    python3 scripts/coverage_feedback.py \
      --input build/guided_regression.json \
      --output build/next_bias.json

For the standalone UVM-shaped example input:

    make -C sim feedback-sample

Run the complete local open-source verification set with:

    make -C sim all

`make -C sim all` now runs the guided abstract regression and uses its actual
coverage artifact as the input to `build/next_bias.json`.

Optional Questa/UVM smoke:

    make -C sim questa UVM_TEST=axi_ucie_smoke_test UVM_SEED=1

Coverage-guided UVM run, after choosing bias knobs:

    make -C sim questa-guided UVM_SEED=42 UVM_PLUSARGS="+BIAS_LONG=1 +BIAS_FIXED=1"

The feedback JSON contains both mapped and unmapped coverage holes. Abstract
`op.read`/`op.write` bins map to the same read/write bias knobs used by the
UVM coverage layer; holes without a current stimulus knob remain visible as
`unmapped_uncovered_bins` instead of being silently discarded.

## Current boundary

The packetized AXI-to-link RTL milestone still supports one AXI data beat per request. A separate UVM reference tunnel now exercises multi-beat AXI channel transport and end-to-end scoreboarding, but it is a methodology model rather than the packetized UCIe bridge. Multiple outstanding transactions, out-of-order completion, and detailed UCIe retry/CRC behavior remain future RTL/UVM integration work. The abstract Python model already exercises credit stalls, CRC retry, timeout retry, reset recovery, and coverage-guided scenario selection.

See docs/VERIFICATION_PLAN.md for the implementation matrix and next steps.
