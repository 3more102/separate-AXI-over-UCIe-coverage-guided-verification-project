import unittest

from cgverif.guidance import CoverageGuidedPlanner
from cgverif.model import CoverageTracker, SCENARIO_KINDS


class GuidanceTests(unittest.TestCase):
    def test_every_arm_is_tried_before_reuse(self):
        planner = CoverageGuidedPlanner(seed=7)
        selected = []
        for _ in SCENARIO_KINDS:
            kind = planner.choose()
            selected.append(kind)
            planner.update(kind, 0.0)

        self.assertEqual(set(selected), set(SCENARIO_KINDS))
        self.assertEqual(len(selected), len(set(selected)))

    def test_guided_run_reaches_required_coverage(self):
        planner = CoverageGuidedPlanner(seed=1)
        tracker = CoverageTracker()

        for index in range(16):
            planner.step(tracker, seed=100 + index, transactions=4)

        self.assertEqual(tracker.ratio, 1.0)
        self.assertEqual(tracker.missing(), [])


if __name__ == "__main__":
    unittest.main()
