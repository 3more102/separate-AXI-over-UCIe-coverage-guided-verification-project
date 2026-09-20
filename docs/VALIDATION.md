# Validation Status

This repository has three distinct verification layers. Results should be interpreted according to the layer that actually executed.

## Open-source packetized RTL path

The default CI runs the milestone packetized bridge with open-source simulators:

- Icarus Verilog lint and smoke simulation for the single-beat packetized path.
- Verilator reference smoke for the burst-capable reference DUT.
- Python unit tests.
- Deterministic coverage-guided abstract regression.
- Paired baseline-vs-guided experiment.
- Coverage-feedback JSON generation.

The packetized bridge remains a simplified UCIe-style transport milestone, not a full UCIe PHY/Adapter implementation.

## UVM/Questa path

The UVM environment in `tb/axi_ucie_tb_pkg.sv` and `tb/tb_top.sv` uses the burst-capable reference DUT and testbench memory model for AXI semantic verification, scoreboarding, functional coverage, assertions, and coverage-guided plusargs.

This path requires a UVM-capable simulator such as Questa and is not executed by the default open-source CI job.

## Abstract guidance path

The Python model validates deterministic scenario generation, semantic coverage accounting, UCB1 guidance behavior, paired experiment plumbing, and coverage-to-bias feedback.

It is not evidence of UCIe compliance or of real-DUT verification efficiency by itself.

## Evidence policy

A claim about RTL or UVM behavior should be backed by the simulator path that exercised that behavior. Source presence, abstract-model coverage, or successful Python tests should not be presented as proof that an unexecuted commercial-simulator path passed.
