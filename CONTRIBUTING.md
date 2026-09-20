# Contributing

Keep changes independently reviewable across three layers:

1. Packetized RTL and executable SystemVerilog smoke tests.
2. UVM methodology and simulator-specific coverage.
3. Python abstract model and coverage-guidance logic.

Before opening a pull request, run the open-source checks:

    make -C sim all

If Questa or another UVM-capable simulator is available, also run:

    make -C sim questa UVM_TEST=axi_ucie_smoke_test UVM_SEED=1

For coverage-guided changes, record the test, seed, coverage holes targeted, and any bias plusargs used.

Assertions should detect local protocol violations. The scoreboard should detect end-to-end semantic corruption. Coverage must never change pass/fail policy.
