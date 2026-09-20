import unittest

from cgverif.model import CoverageTracker, SCENARIO_KINDS, Scenario, run_scenario


class ModelTests(unittest.TestCase):
    def test_every_scenario_preserves_exactly_once_delivery(self):
        for index, kind in enumerate(SCENARIO_KINDS):
            with self.subTest(kind=kind):
                result = run_scenario(
                    Scenario(kind=kind, transactions=31, seed=100 + index)
                )
                self.assertTrue(result.passed)
                self.assertEqual(result.sent, result.received)

    def test_fault_scenarios_retry(self):
        for kind in ("crc_retry", "timeout_retry"):
            result = run_scenario(Scenario(kind=kind, transactions=8, seed=3))
            self.assertGreaterEqual(result.retries, 1)
            self.assertIn("recovery.retry", result.coverage_hits)

    def test_required_coverage_is_reachable(self):
        cov = CoverageTracker()
        for index, kind in enumerate(SCENARIO_KINDS):
            result = run_scenario(
                Scenario(
                    kind=kind,
                    transactions=4,
                    max_outstanding=4,
                    seed=index,
                )
            )
            cov.hit(*result.coverage_hits)
        self.assertEqual(cov.ratio, 1.0)
        self.assertEqual(cov.missing(), [])

    def test_hit_counts_preserve_repeated_samples_and_zero_bins(self):
        cov = CoverageTracker()
        cov.hit("op.read", "integrity.no_loss")
        cov.hit("op.read")

        counts = cov.as_bin_counts()
        self.assertEqual(counts["op.read"], 2)
        self.assertEqual(counts["integrity.no_loss"], 1)
        self.assertEqual(counts["error.crc"], 0)
        self.assertEqual(set(counts), set(CoverageTracker.REQUIRED_BINS))


if __name__ == "__main__":
    unittest.main()
