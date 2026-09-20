import unittest

from cgverif.guidance import CoverageGuidedPlanner
from cgverif.model import CoverageTracker, SCENARIO_KINDS


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


if __name__ == "__main__":
    unittest.main()
