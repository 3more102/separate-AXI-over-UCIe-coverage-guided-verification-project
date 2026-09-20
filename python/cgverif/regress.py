from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

from .guidance import CoverageGuidedPlanner
from .model import CoverageTracker, SCENARIO_KINDS, Scenario, run_scenario


def run_baseline(iterations: int, seed: int, transactions: int) -> dict:
    rng = random.Random(seed)
    coverage = CoverageTracker()
    history = []
    for i in range(iterations):
        scenario = Scenario(
            kind=rng.choice(SCENARIO_KINDS),
            transactions=transactions,
            max_outstanding=rng.randint(1, 8),
            seed=seed + i,
        )
        result = run_scenario(scenario)
        coverage.hit(*result.coverage_hits)
        history.append(
            {"iteration": i, "kind": scenario.kind, "coverage": coverage.ratio}
        )
    return _report("baseline", coverage, history)


def run_guided(iterations: int, seed: int, transactions: int) -> dict:
    coverage = CoverageTracker()
    planner = CoverageGuidedPlanner(seed=seed)
    history = []
    for i in range(iterations):
        scenario, reward = planner.step(
            coverage,
            seed=seed + i,
            transactions=transactions,
        )
        history.append(
            {
                "iteration": i,
                "kind": scenario.kind,
                "reward": reward,
                "coverage": coverage.ratio,
            }
        )
    return _report("guided", coverage, history)


def _report(mode: str, coverage: CoverageTracker, history: list[dict]) -> dict:
    first_full = next(
        (h["iteration"] + 1 for h in history if h["coverage"] == 1.0),
        None,
    )
    return {
        "mode": mode,
        "coverage_bins_hit": coverage.covered,
        "coverage_bins_total": coverage.total,
        "coverage_ratio": coverage.ratio,
        "tests_to_full_coverage": first_full,
        "missing_bins": coverage.missing(),
        "bins": coverage.as_bin_counts(),
        "history": history,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Abstract AXI-over-UCIe coverage regression"
    )
    parser.add_argument("--mode", choices=("baseline", "guided"), default="guided")
    parser.add_argument("--iterations", type=int, default=32)
    parser.add_argument("--transactions", type=int, default=16)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()

    if args.iterations <= 0 or args.transactions <= 0:
        parser.error("iterations and transactions must be > 0")

    fn = run_guided if args.mode == "guided" else run_baseline
    report = fn(args.iterations, args.seed, args.transactions)
    encoded = json.dumps(report, indent=2)
    print(encoded)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(encoded + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
