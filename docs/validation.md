# Validation Status

This repository currently has two complementary verification paths.

## Open-source CI path

The GitHub Actions workflow runs:

- Icarus Verilog lint of the active smoke-test file list.
- RTL smoke simulation using `rtl/axi_ucie_bridge.sv` and `rtl/ucie_mem_endpoint.sv`.
- Python unit tests under `tests/`.
- A deterministic coverage-guided abstract regression.
- Coverage-feedback JSON generation.

The active RTL smoke bridge is intentionally milestone-level: it accepts single-beat AXI requests and rejects unsupported multi-beat bursts locally.

## UVM reference path

The UVM environment in `tb/axi_ucie_tb_pkg.sv` and `tb/tb_top.sv` uses `rtl/axi_ucie_reference_dut.sv` plus `tb/models/axi_memory_slave.sv`. That path is intended to exercise AXI burst semantics, end-to-end scoreboarding, SVA, functional coverage, and coverage-guided plusargs.

This UVM path requires a UVM-capable simulator such as Questa. It is not covered by the current Icarus CI job.

## Coverage guidance

The Python UCB1 planner now has dedicated tests for:

- one-pass warm-up across every scenario arm;
- reward accounting and mean reward;
- deterministic regression results for a fixed seed;
- reachability of all declared abstract coverage bins;
- baseline report schema and coverage bounds.

Claims about simulator correctness should be tied to captured simulator logs and coverage databases, not only to source presence.
