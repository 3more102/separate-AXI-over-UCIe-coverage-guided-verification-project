import json
import tempfile
import unittest
from pathlib import Path

from scripts.coverage_feedback import (
    derive_knobs,
    inverse_frequency_weights,
    load_counts,
)


class CoverageFeedbackTests(unittest.TestCase):
    def test_zero_hit_bin_gets_more_weight(self):
        weights = inverse_frequency_weights({"rare": 0, "common": 24})
        self.assertGreater(weights["rare"], weights["common"])

    def test_weights_are_never_zero(self):
        weights = inverse_frequency_weights({"x": 10_000}, floor=1)
        self.assertEqual(weights["x"], 1)

    def test_derive_knobs_prefers_weak_error_coverage(self):
        weights = {
            "read": 10,
            "write": 20,
            "aw_before_w": 7,
            "w_before_aw": 8,
            "link_backpressure": 3,
            "read_backpressure": 12,
            "write_resp_error": 40,
            "read_resp_error": 5,
        }
        knobs = derive_knobs(weights)
        self.assertEqual(knobs["BIAS_ERROR_ADDR"], 40)
        self.assertEqual(knobs["BIAS_BACKPRESSURE"], 12)

    def test_load_counts_fills_missing_bins_with_zero(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "cov.json"
            path.write_text(json.dumps({"bins": {"read": 4}}))
            counts = load_counts(path)
            self.assertEqual(counts["read"], 4)
            self.assertEqual(counts["write"], 0)

    def test_negative_count_rejected(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "cov.json"
            path.write_text(json.dumps({"bins": {"read": -1}}))
            with self.assertRaises(ValueError):
                load_counts(path)


if __name__ == "__main__":
    unittest.main()
