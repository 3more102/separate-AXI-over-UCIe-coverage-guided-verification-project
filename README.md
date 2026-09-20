# Separate AXI-over-UCIe Coverage-Guided Verification

A SystemVerilog/UVM verification project for an AXI transaction path transported over a simplified UCIe-style link abstraction. The repository is organized so protocol checking, functional coverage, scoreboarding, and coverage-guided stimulus are separated from the DUT/reference transport model.

## Goals

- Verify AXI4 request/response behavior across an AXI-to-link-to-AXI path.
- Check ordering, IDs, bursts, backpressure, reset recovery, and response propagation.
- Model transport faults and link stalls without coupling them to AXI stimulus.
- Use functional coverage feedback to bias future stimulus toward uncovered scenarios.
- Keep a lightweight open-source smoke layer separate from the full UVM regression.

## Repository layout

```text
rtl/                 Reference transport/DUT model
tb/interfaces/       AXI and link interfaces
tb/agents/           UVM AXI + link agents
tb/env/              Scoreboard, coverage collector, environment
tb/sequences/        Directed, random, and coverage-guided sequences
tb/tests/            UVM tests
tb/assertions/       SVA protocol checks
sim/                 File lists and simulator scripts
scripts/             Coverage feedback/regression helpers
docs/                Architecture and verification plan
.github/workflows/    CI smoke/lint
```

## Verification strategy

The testbench keeps **protocol stimulus**, **transport behavior**, and **coverage feedback** independent:

1. AXI sequences generate reads/writes with constrained IDs, lengths, sizes, and address classes.
2. The reference bridge converts accepted AXI operations into link packets and reconstructs responses.
3. Monitors publish observed transactions to the scoreboard and coverage collector.
4. The scoreboard compares end-to-end AXI semantics rather than internal packet timing.
5. Coverage feedback exports uncovered bins to a small JSON file; the next run biases sequence knobs toward those bins.

The UCIe side here is intentionally a **verification abstraction**, not a claim of full UCIe PHY/adapter compliance. It is a packetized ready/valid transport boundary suitable for studying AXI-over-die-to-die verification methodology.

## Quick start

Commercial UVM simulator example:

```bash
cd sim
make questa TEST=axi_ucie_smoke_test SEED=1
make questa TEST=axi_ucie_cov_guided_test SEED=42
```

Open-source smoke/lint:

```bash
make -C sim lint
make -C sim smoke
```

Coverage feedback helper:

```bash
python3 scripts/coverage_feedback.py --input build/coverage.json --output build/next_bias.json
```

## Initial milestone

The first milestone provides a compilable reference path, interfaces, protocol assertions, a UVM environment skeleton with end-to-end scoreboarding, a coverage model, and a coverage-guided sequence hook. The next milestones should add full burst data checking, richer UCIe packet/error modeling, and simulator-specific coverage database merging.
