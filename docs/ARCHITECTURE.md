# Architecture

## Project boundary

This project verifies AXI traffic transported over a **digital UCIe/FDI-style abstraction**. It does not claim UCIe electrical/PHY compliance and does not model analog SerDes behavior.

## End-to-end path

```text
AXI master / UVM AXI agent
        |
        v
AXI -> UCIe bridge DUT
(packetization, queues, IDs/order, credits, CRC/retry)
        |
        v
Abstract FDI/link agent
(backpressure, credit starvation, fault injection, reset)
        |
        v
UCIe -> AXI bridge / sink model
        |
        v
Scoreboard + assertions + functional coverage
        |
        v
Coverage data -> Python planner -> next scenario/seed
```

## Current implementation

The repository currently has two executable layers:

1. **RTL smoke path**: a single-beat AXI4 subset bridge, an abstract UCIe-style memory endpoint, and an end-to-end smoke test.
2. **Coverage-guidance reference path**: a deterministic Python model that closes the loop between scenario selection, coverage accounting, and a UCB1 planner.

The Python layer is a planning/oracle scaffold. It is not a replacement for RTL/UVM coverage.

## Coverage-guided loop

The first planner uses UCB1. Each scenario family is an arm. Reward is the number of newly hit coverage bins. This keeps the policy explainable and seed-replayable while leaving room for later mutation/splicing, novelty scoring, and learned policies.
