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
- Coverage-hole to next-run plusarg bias helper.
- Python unit tests, Icarus smoke/lint, and GitHub Actions CI.

## Repository layout

    rtl/                 Reference RTL transport path
    tb/interfaces/       AXI interface
    tb/assertions/       Protocol SVA
    tb/models/           Testbench models
    tb/smoke/            Open-source executable smoke test
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

Coverage feedback:

    python3 scripts/coverage_feedback.py \
      --input examples/coverage.sample.json \
      --output build/next_bias.json

Run the complete local open-source verification set with:

    make -C sim all

## Current boundary

The RTL milestone supports one AXI data beat per request. Multi-beat bursts,
multiple outstanding transactions, out-of-order completion, and detailed UCIe
retry/CRC behavior are the next RTL/UVM milestones. The abstract Python model
already exercises credit stalls, CRC retry, timeout retry, reset recovery, and
coverage-guided scenario selection.

See docs/VERIFICATION_PLAN.md for the implementation matrix and next steps.
