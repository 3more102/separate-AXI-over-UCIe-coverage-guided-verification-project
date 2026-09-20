# Baseline vs Coverage-Guided Experiment

## Purpose

The experiment harness compares two scenario-selection policies under the same test budget:

- **Baseline:** randomly choose one of the supported scenario classes.
- **Guided:** use UCB1 and reward a scenario only when it discovers new semantic coverage bins.

Both policies run against the same abstract AXI-over-link oracle and use the same top-level seed set, iteration count, and transactions-per-test setting.

## Run

```bash
PYTHONPATH=python python -m cgverif.experiment \
  --runs 20 \
  --iterations 32 \
  --transactions 16 \
  --seed 1 \
  --out build/experiment.json
```

The JSON report contains:

- experiment configuration,
- number of runs reaching full semantic coverage,
- mean/min/max final coverage,
- mean and median tests to full coverage for runs that closed,
- paired per-seed baseline/guided results,
- missing bins when a run does not close.

## Fair-comparison rules

1. Keep the same number of tests in each baseline/guided pair.
2. Keep the same transactions-per-test budget.
3. Use the same set of top-level seeds.
4. Do not discard failing or non-closing seeds from the summary.
5. Report distributions across runs rather than a single favorable seed.
6. When moving to RTL/UVM, measure both test count and wall-clock time because guided stimulus may add orchestration overhead.

## Interpretation limit

The current Python oracle deliberately maps scenario classes to semantic coverage behavior. It is useful for validating the selection algorithm, report format, and regression plumbing, but **it is not evidence that coverage guidance is better on a real UCIe implementation**.

A project-level verification-efficiency claim should only be made after the same fixed-budget experiment is connected to measured RTL/UVM coverage from the DUT.
