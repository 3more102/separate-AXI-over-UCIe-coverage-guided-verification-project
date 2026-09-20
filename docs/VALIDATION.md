# Validation Status

This repository currently has two complementary verification paths.

## Open-source CI path

GitHub Actions runs:

- Python syntax checking.
- Icarus Verilog lint of the active smoke-test file list.
- RTL smoke simulation using `rtl/axi_ucie_bridge.sv` and `rtl/ucie_mem_endpoint.sv`.
- Python unit tests under `tests/`.
- A deterministic coverage-guided abstract regression.
- The paired baseline-vs-guided experiment.
- Coverage-feedback JSON generation.

The packetized RTL smoke bridge is a milestone implementation: it accepts single-beat AXI requests and rejects unsupported multi-beat bursts locally.

## UVM reference path

The UVM environment in `tb/axi_ucie_tb_pkg.sv` and `tb/tb_top.sv` uses `rtl/axi_ucie_reference_dut.sv` with the testbench memory model. This path exercises burst-capable AXI semantics, end-to-end scoreboarding, SVA, functional coverage, and coverage-guided plusargs.

This path requires a UVM-capable simulator such as Questa and is not executed by the Icarus CI job.

## Coverage guidance validation

Dedicated Python tests cover:

- one-pass warm-up across every scenario arm;
- reward accounting and mean reward;
- deterministic seeded regressions;
- reachability of all declared abstract coverage bins;
- baseline report schema and coverage bounds;
- paired experiment determinism and input validation.

Claims about simulator correctness should be tied to captured simulator logs and coverage databases, not only to source presence.
