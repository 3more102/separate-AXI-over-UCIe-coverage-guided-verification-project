import importlib.util
import pathlib
import unittest


MODULE_PATH = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "coverage_feedback.py"
SPEC = importlib.util.spec_from_file_location("coverage_feedback", MODULE_PATH)
coverage_feedback = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(coverage_feedback)


class CoverageFeedbackTests(unittest.TestCase):
    def test_object_form_and_bias_mapping(self):
        bins = coverage_feedback.normalize_bins(
            {"bins": {"len.long": 0, "kind.read": 4, "burst.fixed": 0}}
        )
        result = coverage_feedback.build_bias(bins)
        self.assertEqual(result["uncovered_bins"], ["burst.fixed", "len.long"])
        self.assertEqual(result["bias_knobs"], ["BIAS_FIXED", "BIAS_LONG"])
        self.assertEqual(result["plusargs"], ["+BIAS_FIXED=1", "+BIAS_LONG=1"])
        self.assertEqual(
            result["plusargs_string"],
            "+BIAS_FIXED=1 +BIAS_LONG=1",
        )

    def test_list_form(self):
        bins = coverage_feedback.normalize_bins(
            {"bins": [{"name": "kind.write", "hits": 0}, {"name": "kind.read", "hits": 2}]}
        )
        self.assertEqual(bins, {"kind.write": 0, "kind.read": 2})

    def test_threshold(self):
        result = coverage_feedback.build_bias({"len.medium": 2}, hit_threshold=3)
        self.assertEqual(result["bias_knobs"], ["BIAS_MEDIUM"])

    def test_abstract_regression_aliases_map_to_uvm_knobs(self):
        result = coverage_feedback.build_bias(
            {
                "op.read": 0,
                "op.write": 2,
                "error.crc": 0,
            }
        )
        self.assertEqual(result["bias_knobs"], ["BIAS_READ"])
        self.assertEqual(result["mapped_uncovered_bins"], ["op.read"])
        self.assertEqual(result["unmapped_uncovered_bins"], ["error.crc"])

    def test_negative_hit_count_is_rejected(self):
        with self.assertRaises(ValueError):
            coverage_feedback.normalize_bins({"bins": {"kind.read": -1}})

    def test_nonpositive_threshold_is_rejected(self):
        with self.assertRaises(ValueError):
            coverage_feedback.build_bias({"kind.read": 0}, hit_threshold=0)


if __name__ == "__main__":
    unittest.main()
