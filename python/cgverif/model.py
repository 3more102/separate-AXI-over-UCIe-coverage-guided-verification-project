from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable
import random


SCENARIO_KINDS = (
    "read",
    "write",
    "partial_write",
    "backpressure",
    "credit_stall",
    "crc_retry",
    "timeout_retry",
    "reset_recovery",
)


@dataclass(frozen=True)
class Scenario:
    kind: str
    transactions: int = 16
    max_outstanding: int = 4
    seed: int = 1

    def __post_init__(self) -> None:
        if self.kind not in SCENARIO_KINDS:
            raise ValueError(f"unsupported scenario kind: {self.kind}")
        if self.transactions <= 0:
            raise ValueError("transactions must be > 0")
        if self.max_outstanding <= 0:
            raise ValueError("max_outstanding must be > 0")


@dataclass
class CoverageTracker:
    bins: set[str] = field(default_factory=set)

    REQUIRED_BINS = frozenset(
        {
            "op.read",
            "op.write",
            "strobe.partial",
            "flow.backpressure",
            "flow.credit_zero",
            "error.crc",
            "recovery.retry",
            "error.timeout",
            "recovery.reset",
            "outstanding.gt1",
            "ordering.in_order",
            "integrity.no_loss",
            "integrity.no_dup",
        }
    )

    def hit(self, *names: str) -> None:
        self.bins.update(names)

    @property
    def covered(self) -> int:
        return len(self.bins & self.REQUIRED_BINS)

    @property
    def total(self) -> int:
        return len(self.REQUIRED_BINS)

    @property
    def ratio(self) -> float:
        return self.covered / self.total

    def missing(self) -> list[str]:
        return sorted(self.REQUIRED_BINS - self.bins)


@dataclass(frozen=True)
class SimulationResult:
    sent: int
    received: int
    retries: int
    coverage_hits: frozenset[str]

    @property
    def passed(self) -> bool:
        return self.sent == self.received


def _base_hits(kind: str) -> set[str]:
    hits = {"ordering.in_order", "integrity.no_loss", "integrity.no_dup"}
    if kind == "read":
        hits.add("op.read")
    else:
        hits.add("op.write")
    if kind == "partial_write":
        hits.add("strobe.partial")
    elif kind == "backpressure":
        hits.add("flow.backpressure")
    elif kind == "credit_stall":
        hits.add("flow.credit_zero")
    elif kind == "crc_retry":
        hits.update({"error.crc", "recovery.retry"})
    elif kind == "timeout_retry":
        hits.update({"error.timeout", "recovery.retry"})
    elif kind == "reset_recovery":
        hits.add("recovery.reset")
    return hits


def run_scenario(scenario: Scenario) -> SimulationResult:
    """Run a deterministic abstract transport model.

    This is intentionally not a UCIe PHY model. It is a transaction/link-level
    oracle used to exercise the coverage-guidance loop before a real RTL/UVM DUT
    adapter is attached.
    """
    rng = random.Random(scenario.seed)
    hits = _base_hits(scenario.kind)
    if scenario.max_outstanding > 1:
        hits.add("outstanding.gt1")

    retries = 0
    sent = scenario.transactions
    received = 0

    for _ in range(scenario.transactions):
        if scenario.kind in {"crc_retry", "timeout_retry"}:
            if received == 0 or rng.random() < 0.25:
                retries += 1
        received += 1

    return SimulationResult(
        sent=sent,
        received=received,
        retries=retries,
        coverage_hits=frozenset(hits),
    )


def merge_coverage(tracker: CoverageTracker, results: Iterable[SimulationResult]) -> None:
    for result in results:
        tracker.hit(*result.coverage_hits)
