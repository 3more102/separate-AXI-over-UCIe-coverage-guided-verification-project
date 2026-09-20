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
- Coverage JSON to next-run bias conversion.
- Python unit tests and an Icarus-based smoke/lint flow.
- GitHub Actions CI that runs all of the above.

## Verification matrix

| Area | Current | Next |
| --- | --- | --- |
| AXI read/write | Single beat | Full multi-beat |
| AW/W decoupling | Covered | Randomized timing expansion |
| AXI response backpressure | Covered | Cross with bursts and IDs |
| Link request stall | Covered | Random stall distributions |
| IDs | Preserved end-to-end | Multiple outstanding and reordering |
| Partial write | UVM stimulus + coverpoint + feedback bias | Add RTL smoke cross-coverage |
| Reset recovery | Smoke + abstract model | Mid-burst and multi-outstanding reset |
| Link errors | Abstract CRC/timeout retry model | RTL/UVM fault injection |
| Functional coverage | Abstract bins + feedback | Simulator covergroups and crosses |
| Assertions | Ready/valid stability | Ordering, burst legality, liveness |

## Coverage targets for the UVM milestone

The UVM environment should cover operation, burst length/type, size, address
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
3. Convert coverage holes into stimulus bias.
4. Apply the bias only to future stimulus probabilities.
5. Never change checkers, assertions, or pass/fail policy based on coverage.

## Next implementation milestone

1. Packetize full AXI INCR/FIXED/WRAP bursts.
2. Add configurable multiple outstanding transactions.
3. Add ID-aware reorder checking.
4. Build UVM AXI and link agents plus scoreboard and coverage subscriber.
5. Add link fault injection and retry/status modeling.
6. Export simulator coverage into the neutral JSON feedback path.
