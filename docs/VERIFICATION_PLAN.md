# Verification Plan

## Scope

This repository verifies AXI transactions transported through a packetized
UCIe-style ready/valid abstraction. The link is a verification transport model;
it is not a full UCIe PHY or Adapter implementation.

## Current executable milestone

The repository currently contains:

- A single-outstanding AXI-to-link bridge with per-beat FIXED and INCR burst packetization.
- A byte-addressable link-side memory endpoint with write-strobe handling.
- AXI interface and protocol-stability assertions.
- An open-source SystemVerilog smoke test covering single-beat traffic, multi-beat FIXED/INCR bursts, link stalls, AXI response backpressure, local WRAP rejection, and reset recovery.
- Local SLVERR handling for unsupported WRAP/reserved burst types and transfer sizes wider than the data bus.
- A deterministic Python transaction/link model.
- Coverage-guided scenario selection using a UCB1 planner.
- Coverage JSON to next-run bias conversion.
- UVM AXI driver/sequencer, dual monitors, semantic end-to-end scoreboard, covergroups, and coverage-guided sequence running against a separate burst-capable channel-tunnel reference DUT.
- Python unit tests and an Icarus-based smoke/lint flow.
- GitHub Actions CI for the open-source flow; Questa/UVM is an optional local target.

## Packetized bridge policy

The bridge converts each accepted AXI burst beat into one request on the
UCIe-style link. It keeps at most one link request in flight, which makes
response association deterministic while the packet format and checking
strategy mature.

For writes, AW metadata remains active across the burst, W beats are forwarded
one at a time, link response errors are accumulated, and one AXI B response is
returned after the final beat. For reads, the bridge advances the effective
address after each accepted AXI R beat and emits RLAST only on the final beat.
FIXED holds the effective address constant; INCR advances by 2^SIZE bytes.

## Verification matrix

| Area | Current | Next |
| --- | --- | --- |
| Packetized AXI read/write RTL | FIXED/INCR bursts, one link request per beat | WRAP addressing + deeper pipelining |
| UVM methodology path | Burst-capable reference tunnel + scoreboard | Connect to packetized bridge/link agent |
| AW/W decoupling | One-beat W buffering + packetized smoke | Randomized timing expansion |
| AXI response backpressure | Covered, including multi-beat reads | Cross with IDs and link stalls |
| Link request stall | Covered inside burst traffic | Random stall distributions |
| IDs | Preserved end-to-end for single outstanding flow | Multiple outstanding and reordering |
| Partial write | Endpoint/bridge datapath supports WSTRB | Add explicit packetized smoke + UVM coverage |
| Reset recovery | Packetized smoke + abstract model | Mid-burst and multi-outstanding reset |
| Link errors | Write response accumulation + abstract CRC/timeout retry model | RTL/UVM fault injection |
| Functional coverage | Abstract bins + feedback + UVM covergroups | Export/merge simulator coverage |
| Assertions | Ready/valid stability | Burst legality, order, no-loss/no-duplication, liveness |

## UVM coverage layer

The UVM environment currently covers operation, burst length class, FIXED/INCR
burst type, transfer size, and the operation x length x burst cross. The
coverage-guided sequence accepts BIAS_LONG, BIAS_MEDIUM, BIAS_FIXED, BIAS_INCR,
BIAS_READ, and BIAS_WRITE plusargs.

The next UVM expansion should cover address alignment and boundary class, ID,
outstanding depth, AXI channel backpressure, link stalls, response type,
retry/error class, and reset timing.

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

1. Replace the UVM reference channel tunnel with the packetized AXI-over-UCIe bridge and a dedicated link agent.
2. Add explicit packetized partial-write, WLAST-error, and response-error tests.
3. Add WRAP burst address generation and legality checks.
4. Add configurable multiple outstanding transactions and ID-aware reorder checking.
5. Add link fault injection and retry/status modeling.
6. Export and merge simulator coverage into the neutral JSON feedback path.
