from __future__ import annotations

from dataclasses import dataclass
import math
import random

from .model import CoverageTracker, SCENARIO_KINDS, Scenario, run_scenario


@dataclass
class _Arm:
    pulls: int = 0
    reward_sum: float = 0.0

    @property
    def mean(self) -> float:
        return self.reward_sum / self.pulls if self.pulls else 0.0


class CoverageGuidedPlanner:
    """Small UCB1 planner that rewards new coverage bins."""

    def __init__(self, seed: int = 1) -> None:
        self.rng = random.Random(seed)
        self.arms = {kind: _Arm() for kind in SCENARIO_KINDS}
        self.total_pulls = 0

    def choose(self) -> str:
        untried = [name for name, arm in self.arms.items() if arm.pulls == 0]
        if untried:
            return self.rng.choice(untried)

        log_n = math.log(self.total_pulls)
        return max(
            self.arms,
            key=lambda name: self.arms[name].mean
            + math.sqrt(2.0 * log_n / self.arms[name].pulls),
        )

    def update(self, kind: str, reward: float) -> None:
        arm = self.arms[kind]
        arm.pulls += 1
        arm.reward_sum += reward
        self.total_pulls += 1

    def step(
        self,
        tracker: CoverageTracker,
        *,
        seed: int,
        transactions: int = 16,
    ) -> tuple[Scenario, float]:
        kind = self.choose()
        before = tracker.covered
        scenario = Scenario(
            kind=kind,
            transactions=transactions,
            max_outstanding=self.rng.randint(1, 8),
            seed=seed,
        )
        result = run_scenario(scenario)
        if not result.passed:
            raise AssertionError(f"transport integrity failed for {scenario}")
        tracker.hit(*result.coverage_hits)
        reward = float(tracker.covered - before)
        self.update(kind, reward)
        return scenario, reward
