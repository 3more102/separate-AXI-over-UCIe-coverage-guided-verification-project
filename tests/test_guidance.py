import unittest

from cgverif.guidance import CoverageGuidedPlanner
from cgverif.model import CoverageTracker
from cgverif.regress import run_guided


class GuidanceTests(unittest.TestCase):
    def test_planner_is_seed_replayable(self):
        def trace():
            planner = CoverageGuidedPlanner(seed=77)
            cov = CoverageTracker()
            return [planner.step(cov, seed=i)[0].kind for i in range(16)]

        self.assertEqual(trace(), trace())

    def test_guided_smoke_reaches_all_abstract_bins(self):
        report = run_guided(iterations=16, seed=9, transactions=8)
        self.assertEqual(report["coverage_ratio"], 1.0)
        self.assertEqual(report["missing_bins"], [])


if __name__ == "__main__":
    unittest.main()
