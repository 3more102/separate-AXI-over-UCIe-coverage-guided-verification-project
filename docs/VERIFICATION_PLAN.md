# Verification Plan

## Scope

This repository verifies AXI transactions transported through a packetized
UCIe-style ready/valid abstraction. The link is a verification transport model;
it is not a full UCIe PHY or Adapter implementation.

## Current executable milestone

The repository currently contains:

- A single-beat AXI-to-link bridge and a link-side memory endpoint.
- AXI interface and protocol-stability assertions.
- An open-source SystemVerilog smoke test with link and response backpressure.
- Explicit rejection of unsupported multi-beat requests.
- A deterministic Python transaction/link model.
- Coverage-guided scenario selection using a UCB1 planner.
- Per-bin neutral coverage hit-count export, including zero-hit bins.
- Coverage JSON to next-run bias conversion with explicit mapped/unmapped holes.
- UVM AXI driver/sequencer, dual monitors, semantic end-to-end scoreboard, covergroups, and coverage-guided sequence running against a separate burst-capable channel-tunnel reference DUT.
- Python unit tests and an Icarus-based smoke/lint flow.
- GitHub Actions CI for the open-source flow; Questa/UVM is an optional local target.

## Verification matrix

| Area | Current | Next |
| --- | --- | --- |
| Packetized AXI read/write RTL | Single beat | Full multi-beat packetization |
| UVM methodology path | Burst-capable reference tunnel + scoreboard | Connect to packetized bridge/link agent |
| AW/W decoupling | Covered in packetized smoke | Randomized timing expansion |
| AXI response backpressure | Covered | Cross with bursts and IDs |
| Link request stall | Covered | Random stall distributions |
| IDs | Preserved end-to-end | Multiple outstanding and reordering |
| Partial write | Abstract model | RTL smoke and UVM sequence |
| Reset recovery | Smoke + abstract model | Mid-burst and multi-outstanding reset |
| Link errors | Abstract CRC/timeout retry model | RTL/UVM fault injection |
| Functional coverage | Abstract bins + hit counts + feedback + UVM covergroups | Export/merge simulator coverage |
| Assertions | Ready/valid stability | Ordering, burst legality, liveness |

## UVM coverage layer

The UVM environment currently covers operation, burst length class, FIXED/INCR burst type, transfer size, and the operation x length x burst cross. The coverage-guided sequence accepts BIAS_LONG, BIAS_MEDIUM, BIAS_FIXED, BIAS_INCR, BIAS_READ, and BIAS_WRITE plusargs.

The next UVM expansion should cover address
alignment and boundary class, ID, outstanding depth, AXI channel backpressure,
link stalls, response type, retry/error class, and reset timing.

High-value crosses include:

- operation x burst length x link stall
- ID x outstanding depth
- response x operation
- reset timing x channel state
- burst type x alignment x boundary class

## Scoreboard policy

End-to-end AXI semantics are the correctness reference. Internal link packets
are useful for diagnostics and coverage, but packet timing must not become the
golden behavior. The scoreboard should compare accepted AXI requests with AXI
responses, including IDs, response status, write strobes, burst beat count, and
read data ordering.

## Coverage-guided loop

1. Run seeded tests and export coverage hit counts.
2. Preserve the seed and coverage report as artifacts.
3. Keep explicit zero-hit bins in the neutral `bins` object.
4. Convert coverage holes into mapped stimulus bias plusargs while retaining
   unmapped holes for visibility.
5. Apply the bias only to future stimulus probabilities.
6. Never change checkers, assertions, or pass/fail policy based on coverage.

The open-source `make -C sim all` flow now executes steps 1-4 using
`build/guided_regression.json` as the input to
`build/next_bias.json`. The same feedback helper also accepts UVM-shaped bin
names. Abstract `op.read` and `op.write` are aliases for the UVM
read/write bias knobs.

## Next implementation milestone

1. Packetize full AXI INCR/FIXED/WRAP bursts.
2. Add configurable multiple outstanding transactions.
3. Add ID-aware reorder checking.
4. Replace the reference channel tunnel in the UVM top with the packetized AXI-over-UCIe bridge plus a dedicated link agent.
5. Add link fault injection and retry/status modeling.
6. Export and merge simulator coverage into the neutral JSON feedback path.
