from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class UvmSourceSanityTests(unittest.TestCase):
    def test_systemverilog_sources_do_not_escape_preprocessor_backticks(self):
        offenders = []
        for base in ("rtl", "tb"):
            for path in sorted((ROOT / base).rglob("*.sv")):
                if "\\`" in path.read_text(encoding="utf-8"):
                    offenders.append(str(path.relative_to(ROOT)))
        self.assertEqual(
            offenders,
            [],
            "escaped SystemVerilog preprocessor backticks found in: "
            + ", ".join(offenders),
        )

    def test_questa_file_list_entries_exist(self):
        file_list = ROOT / "sim" / "files.f"
        missing = []
        for raw in file_list.read_text(encoding="utf-8").splitlines():
            entry = raw.strip()
            if not entry or entry.startswith("#"):
                continue
            candidate = (file_list.parent / entry).resolve()
            if not candidate.is_file():
                missing.append(entry)
        self.assertEqual(
            missing,
            [],
            "missing Questa file-list entries: " + ", ".join(missing),
        )

    def test_guided_uvm_test_is_in_canonical_questa_package(self):
        package = (ROOT / "tb" / "axi_ucie_tb_pkg.sv").read_text(encoding="utf-8")
        self.assertIn("class axi_ucie_cov_guided_test extends uvm_test;", package)
        self.assertIn("class axi_cov_guided_seq extends uvm_sequence #(axi_txn);", package)


if __name__ == "__main__":
    unittest.main()
