# Baseline vs Coverage-Guided Experiment

## Purpose

The experiment harness compares two scenario-selection policies under the same
verification budget:

- **Baseline:** random selection from the supported scenario classes.
- **Guided:** UCB1 selection with reward equal to newly discovered semantic
  coverage bins.

Both policies use the same top-level seed, iteration count, and
transactions-per-test budget for every paired run.

## Run

```bash
PYTHONPATH=python python3 -m cgverif.experiment \
  --runs 20 \
  --iterations 32 \
  --transactions 16 \
  --seed 1 \
  --out build/experiment.json
```

Or run it through the repository Makefile:

```bash
make -C sim experiment
```

## Report contents

The JSON report records:

- experiment configuration;
- full-coverage run counts;
- mean/min/max final coverage for each policy;
- mean/median tests to full coverage for runs that close;
- paired per-seed results;
- per-pair and mean final-coverage deltas;
- missing bins for non-closing runs.

## Fair-comparison rules

1. Use the same test count in each baseline/guided pair.
2. Use the same transactions-per-test budget.
3. Use the same top-level seed set.
4. Keep non-closing runs in the summary.
5. Report multiple seeds, not a single favorable run.
6. When connected to RTL/UVM, report simulator time as well as test count.

## Interpretation boundary

The current Python oracle intentionally maps abstract scenario classes to
semantic coverage behavior. It validates the guidance algorithm, experiment
plumbing, determinism, and report format.

It does **not** establish a performance or compliance claim for a real UCIe
implementation. Project-level efficiency claims require the same fixed-budget
comparison using measured DUT coverage from the RTL/UVM flow.
