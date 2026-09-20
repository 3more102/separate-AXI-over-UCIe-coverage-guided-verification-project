import unittest

from cgverif.guidance import CoverageGuidedPlanner
from cgverif.model import CoverageTracker, SCENARIO_KINDS
from cgverif.regress import run_guided


class GuidanceTests(unittest.TestCase):
    def test_first_exploration_round_visits_every_scenario(self):
        planner = CoverageGuidedPlanner(seed=7)
        chosen = []
        for _ in SCENARIO_KINDS:
            kind = planner.choose()
            chosen.append(kind)
            planner.update(kind, 0.0)

        self.assertEqual(set(chosen), set(SCENARIO_KINDS))
        self.assertEqual(len(chosen), len(set(chosen)))

    def test_guided_run_is_reproducible_for_a_seed(self):
        a = run_guided(iterations=12, seed=11, transactions=8)
        b = run_guided(iterations=12, seed=11, transactions=8)
        self.assertEqual(a, b)

    def test_seed_one_reaches_all_abstract_bins_in_first_round(self):
        report = run_guided(
            iterations=len(SCENARIO_KINDS),
            seed=1,
            transactions=8,
        )
        self.assertEqual(report["coverage_ratio"], 1.0)
        self.assertEqual(report["missing_bins"], [])
        self.assertEqual(report["tests_to_full_coverage"], len(SCENARIO_KINDS))


if __name__ == "__main__":
    unittest.main()
