# Baseline vs Coverage-Guided Experiment

## Purpose

The experiment harness compares two scenario-selection policies under the same test budget:

- **Baseline:** randomly choose one of the supported abstract scenario classes.
- **Guided:** use UCB1 and reward a scenario when it discovers new semantic coverage bins.

Both policies run against the same abstract AXI-over-link oracle and use the same top-level seed set, iteration count, and transactions-per-test setting.

## Run

```bash
PYTHONPATH=python python3 -m cgverif.experiment \
  --runs 20 \
  --iterations 32 \
  --transactions 16 \
  --seed 1 \
  --out build/experiment.json
```

The JSON report contains the experiment configuration, full-coverage run count, final-coverage statistics, tests-to-closure statistics, paired per-seed results, and missing bins for non-closing runs.

## Fair-comparison rules

1. Keep the same number of tests in each baseline/guided pair.
2. Keep the same transactions-per-test budget.
3. Use the same set of top-level seeds.
4. Do not discard failing or non-closing seeds.
5. Report distributions across runs rather than a single favorable seed.
6. When connected to RTL/UVM, measure wall-clock time as well as test count because guidance has orchestration cost.

## Interpretation limit

The current Python oracle deliberately maps scenario classes to semantic coverage behavior. It validates the selection algorithm, report format, determinism, and regression plumbing, but it is **not** evidence that coverage guidance is better on a real UCIe implementation.

A project-level verification-efficiency claim requires the same fixed-budget experiment using measured RTL/UVM coverage from the DUT.
