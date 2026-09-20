# Verification plan

## Milestone-1 DUT scope

The current RTL smoke path supports a **single-beat AXI4 subset**. Requests with `AxLEN != 0` are rejected locally with `SLVERR`. Full burst transport is a later milestone.

## Core properties

- No transaction loss.
- No transaction duplication.
- Preserve required ordering for the supported subset.
- Stable payload/control while a ready/valid transfer is stalled.
- Credit conservation once the credit model is connected.
- CRC/timeout faults produce retry or a classified terminal failure.
- Reset behavior is deterministic and checked.

## Functional coverage

Initial dimensions:

- read vs write;
- burst length/type buckets for the burst-capable path;
- single vs multiple outstanding requests;
- partial write strobes;
- request/response backpressure;
- zero-credit state;
- CRC error and retry;
- timeout and retry;
- reset/recovery;
- operation x flow-control cross;
- error x recovery cross.

## Regression experiment

Run equal-budget campaigns against the same RTL revision:

1. baseline constrained-random scenario selection;
2. coverage-guided selection.

Report measured results only: coverage-vs-test count, tests-to-target coverage, unique failure signatures, minimized reproducer length, and deterministic seed replay. Do not treat Python abstract-model coverage numbers as RTL/UVM coverage.

## Next implementation steps

- Add real AXI and FDI/UCIe monitors.
- Add end-to-end scoreboard semantics for IDs, responses, bursts, and ordering.
- Export simulator coverage summaries to the Python planner.
- Add scenario mutation/splicing and novelty scoring.
- Add failure hashing and delta-debug minimization.
- Add formal checks for FIFO safety, credit conservation, retry state, and loss/duplication invariants.
