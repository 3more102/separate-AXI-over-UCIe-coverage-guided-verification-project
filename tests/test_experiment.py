import unittest

from cgverif.experiment import run_experiment


class ExperimentTests(unittest.TestCase):
    def test_experiment_is_deterministic(self):
        kwargs = dict(runs=5, iterations=16, transactions=4, seed=11)
        self.assertEqual(run_experiment(**kwargs), run_experiment(**kwargs))

    def test_guided_closes_in_fixed_budget_for_reference_model(self):
        report = run_experiment(runs=8, iterations=16, transactions=4, seed=1)
        self.assertEqual(report["guided"]["full_coverage_runs"], 8)
        self.assertEqual(report["guided"]["mean_final_coverage"], 1.0)

    def test_invalid_budget_rejected(self):
        with self.assertRaises(ValueError):
            run_experiment(runs=0, iterations=8, transactions=4, seed=1)


if __name__ == "__main__":
    unittest.main()
