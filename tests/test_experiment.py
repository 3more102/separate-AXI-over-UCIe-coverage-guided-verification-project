import unittest

from cgverif.experiment import run_experiment


class ExperimentTests(unittest.TestCase):
    def test_experiment_is_deterministic(self):
        kwargs = dict(runs=5, iterations=16, transactions=4, seed=11)
        self.assertEqual(run_experiment(**kwargs), run_experiment(**kwargs))

    def test_pairs_use_identical_seed_budget(self):
        report = run_experiment(runs=4, iterations=12, transactions=4, seed=7)

        self.assertEqual(report["configuration"]["runs"], 4)
        self.assertEqual(
            [pair["seed"] for pair in report["paired_runs"]],
            [7, 8, 9, 10],
        )
        for pair in report["paired_runs"]:
            self.assertGreaterEqual(pair["baseline"]["coverage_ratio"], 0.0)
            self.assertLessEqual(pair["baseline"]["coverage_ratio"], 1.0)
            self.assertGreaterEqual(pair["guided"]["coverage_ratio"], 0.0)
            self.assertLessEqual(pair["guided"]["coverage_ratio"], 1.0)

    def test_invalid_budget_rejected(self):
        invalid = (
            dict(runs=0, iterations=8, transactions=4, seed=1),
            dict(runs=1, iterations=0, transactions=4, seed=1),
            dict(runs=1, iterations=8, transactions=0, seed=1),
        )
        for kwargs in invalid:
            with self.subTest(kwargs=kwargs):
                with self.assertRaises(ValueError):
                    run_experiment(**kwargs)


if __name__ == "__main__":
    unittest.main()
