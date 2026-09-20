# Separate AXI-over-UCIe Coverage-Guided Verification

Verification-first project for AXI traffic transported over a simplified **digital UCIe/FDI-style link abstraction**. The goal is to build a measurable coverage-guided verification flow while keeping AXI stimulus, link behavior, checking, and coverage feedback separable.

> Scope: digital protocol/transaction behavior only. This repository does **not** claim UCIe PHY, SerDes, electrical, or certification compliance.

## Implemented now

- Single-beat AXI4-subset to abstract-link bridge.
- Abstract UCIe-style memory endpoint.
- End-to-end SystemVerilog smoke test with request stall, response backpressure, local rejection of unsupported bursts, and reset recovery.
- AXI ready/valid stability assertions.
- AXI interface and reference ready/valid transport model.
- Python coverage model with deterministic scenario replay.
- UCB1 coverage-guided scenario planner.
- Coverage-hole to bias-knob helper.
- Unit tests for the Python planner/model and feedback helper.
- Functional-coverage scaffold for AXI traffic/flow-control dimensions.
- GitHub Actions CI for Python tests and Icarus RTL smoke.

## Repository layout

```text
rtl/                 reference transport/DUT models
tb/interfaces/       AXI interface
tb/models/           AXI memory model
tb/smoke/            open-source end-to-end smoke test
tb/assertions/       SVA protocol checks
tb/coverage/         functional-coverage scaffold
python/cgverif/      coverage model + guided planner
scripts/             coverage-feedback helpers
tests/               Python unit tests
sim/                 Icarus build/run targets
docs/                architecture and verification plan
.github/workflows/    CI
```

## Quick start

Python verification layer:

```bash
PYTHONPATH=python python -m unittest discover -s tests -v
PYTHONPATH=python python -m cgverif.regress --mode baseline --iterations 32 --seed 9 --out reports/baseline.json
PYTHONPATH=python python -m cgverif.regress --mode guided   --iterations 32 --seed 9 --out reports/guided.json
```

RTL smoke with Icarus Verilog:

```bash
make -C sim lint
make -C sim smoke
```

Or run the full open-source milestone:

```bash
make -C sim all
```

Coverage-feedback helper:

```bash
python scripts/coverage_feedback.py \
  --input examples/coverage.sample.json \
  --output reports/next_bias.json
```

## Current limitation

The RTL bridge smoke path is intentionally **single-beat** today: requests with `AxLEN != 0` are rejected locally. Full AXI4 bursts, multiple outstanding transactions in RTL, credit accounting, CRC/retry, timeout recovery, a complete UVM environment, scoreboard, failure minimization, and simulator coverage-database integration remain future milestones.

The Python model already contains abstract scenario categories for several of those future behaviors so the coverage-guidance loop can be developed and tested independently.

See `docs/ARCHITECTURE.md` and `docs/VERIFICATION_PLAN.md`.
