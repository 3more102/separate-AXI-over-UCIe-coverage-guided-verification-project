from __future__ import annotations

import argparse
import json
from pathlib import Path
from statistics import mean, median

from .regress import run_baseline, run_guided


def _mode_summary(reports: list[dict]) -> dict:
    final_ratios = [float(report["coverage_ratio"]) for report in reports]
    closure_tests = [
        int(report["tests_to_full_coverage"])
        for report in reports
        if report["tests_to_full_coverage"] is not None
    ]
    return {
        "runs": len(reports),
        "full_coverage_runs": len(closure_tests),
        "mean_final_coverage": mean(final_ratios),
        "min_final_coverage": min(final_ratios),
        "max_final_coverage": max(final_ratios),
        "mean_tests_to_full_coverage": mean(closure_tests) if closure_tests else None,
        "median_tests_to_full_coverage": median(closure_tests) if closure_tests else None,
    }


def run_experiment(
    *,
    runs: int,
    iterations: int,
    transactions: int,
    seed: int,
) -> dict:
    """Run paired baseline/guided regressions over the same top-level seeds."""
    if runs <= 0 or iterations <= 0 or transactions <= 0:
        raise ValueError("runs, iterations, and transactions must be > 0")

    pairs = []
    baseline_reports = []
    guided_reports = []

    for offset in range(runs):
        run_seed = seed + offset
        baseline = run_baseline(iterations, run_seed, transactions)
        guided = run_guided(iterations, run_seed, transactions)
        baseline_reports.append(baseline)
        guided_reports.append(guided)
        pairs.append(
            {
                "seed": run_seed,
                "baseline": {
                    "coverage_ratio": baseline["coverage_ratio"],
                    "tests_to_full_coverage": baseline["tests_to_full_coverage"],
                    "missing_bins": baseline["missing_bins"],
                },
                "guided": {
                    "coverage_ratio": guided["coverage_ratio"],
                    "tests_to_full_coverage": guided["tests_to_full_coverage"],
                    "missing_bins": guided["missing_bins"],
                },
            }
        )

    return {
        "configuration": {
            "runs": runs,
            "iterations_per_run": iterations,
            "transactions_per_test": transactions,
            "first_seed": seed,
        },
        "baseline": _mode_summary(baseline_reports),
        "guided": _mode_summary(guided_reports),
        "paired_runs": pairs,
        "interpretation_note": (
            "This abstract model validates the experiment harness only; it is not evidence "
            "of UCIe-compliant DUT performance. Use the same harness with measured RTL/UVM "
            "coverage before making verification-efficiency claims."
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Repeatable baseline-vs-guided coverage experiment"
    )
    parser.add_argument("--runs", type=int, default=20)
    parser.add_argument("--iterations", type=int, default=32)
    parser.add_argument("--transactions", type=int, default=16)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()

    try:
        report = run_experiment(
            runs=args.runs,
            iterations=args.iterations,
            transactions=args.transactions,
            seed=args.seed,
        )
    except ValueError as exc:
        parser.error(str(exc))

    encoded = json.dumps(report, indent=2)
    print(encoded)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(encoded + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
