import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
UVM_PKG = ROOT / "tb" / "axi_ucie_tb_pkg.sv"


class UvmSourceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = UVM_PKG.read_text(encoding="utf-8")

    def test_write_strobes_are_randomizable(self):
        self.assertIn(
            "rand bit [AXI_STRB_W-1:0] strb_q[$];",
            self.source,
        )

    def test_partial_write_has_coverage_and_guidance_hooks(self):
        for token in (
            "partial_write",
            "cp_partial",
            'BIAS_PARTIAL',
        ):
            with self.subTest(token=token):
                self.assertIn(token, self.source)


if __name__ == "__main__":
    unittest.main()
