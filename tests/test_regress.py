import unittest

from cgverif.model import CoverageTracker, SCENARIO_KINDS
from cgverif.regress import run_guided


class RegressionReportTests(unittest.TestCase):
    def test_guided_report_exports_complete_bin_count_map(self):
        report = run_guided(
            iterations=len(SCENARIO_KINDS),
            seed=11,
            transactions=4,
        )

        self.assertEqual(report["mode"], "guided")
        self.assertEqual(
            set(report["bins"]),
            set(CoverageTracker.REQUIRED_BINS),
        )
        self.assertGreaterEqual(report["bins"]["op.read"], 1)
        self.assertGreaterEqual(report["bins"]["op.write"], 1)
        self.assertTrue(all(hits >= 0 for hits in report["bins"].values()))

    def test_missing_bins_match_zero_hit_bins(self):
        report = run_guided(iterations=1, seed=3, transactions=2)
        zero_hit_bins = sorted(
            name for name, hits in report["bins"].items() if hits == 0
        )
        self.assertEqual(report["missing_bins"], zero_hit_bins)


if __name__ == "__main__":
    unittest.main()
