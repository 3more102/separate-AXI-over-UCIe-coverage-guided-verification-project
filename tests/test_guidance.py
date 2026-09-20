import unittest

from cgverif.guidance import CoverageGuidedPlanner
from cgverif.model import CoverageTracker, SCENARIO_KINDS
from cgverif.regress import run_baseline, run_guided


class GuidanceTests(unittest.TestCase):
    def test_every_arm_is_explored_before_repeat(self):
        planner = CoverageGuidedPlanner(seed=7)
        coverage = CoverageTracker()
        seen = set()

        for i in range(len(SCENARIO_KINDS)):
            scenario, reward = planner.step(
                coverage,
                seed=100 + i,
                transactions=4,
            )
            seen.add(scenario.kind)
            self.assertGreaterEqual(reward, 0.0)

        self.assertEqual(seen, set(SCENARIO_KINDS))
        self.assertEqual(planner.total_pulls, len(SCENARIO_KINDS))
        self.assertTrue(all(arm.pulls == 1 for arm in planner.arms.values()))

    def test_updates_accumulate_reward(self):
        planner = CoverageGuidedPlanner(seed=1)
        planner.update("read", 3.0)
        planner.update("read", 1.0)

        self.assertEqual(planner.arms["read"].pulls, 2)
        self.assertEqual(planner.arms["read"].reward_sum, 4.0)
        self.assertEqual(planner.arms["read"].mean, 2.0)
        self.assertEqual(planner.total_pulls, 2)

    def test_guided_report_is_deterministic_for_seed(self):
        first = run_guided(iterations=24, seed=3, transactions=8)
        second = run_guided(iterations=24, seed=3, transactions=8)

        self.assertEqual(first, second)
        self.assertEqual(len(first["history"]), 24)
        self.assertEqual(first["mode"], "guided")

    def test_guided_reaches_all_declared_bins(self):
        report = run_guided(iterations=24, seed=1, transactions=8)

        self.assertEqual(report["coverage_ratio"], 1.0)
        self.assertEqual(report["missing_bins"], [])
        self.assertIsNotNone(report["tests_to_full_coverage"])

    def test_baseline_report_schema_and_bounds(self):
        report = run_baseline(iterations=12, seed=11, transactions=4)

        self.assertEqual(report["mode"], "baseline")
        self.assertEqual(len(report["history"]), 12)
        self.assertGreaterEqual(report["coverage_ratio"], 0.0)
        self.assertLessEqual(report["coverage_ratio"], 1.0)


if __name__ == "__main__":
    unittest.main()
