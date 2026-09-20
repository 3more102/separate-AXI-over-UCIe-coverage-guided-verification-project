#!/usr/bin/env python3
"""Convert functional coverage holes into bias knobs for the next regression run."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


BIAS_RULES = {
    # UVM functional-coverage bin names.
    "len.long": "BIAS_LONG",
    "len.medium": "BIAS_MEDIUM",
    "burst.fixed": "BIAS_FIXED",
    "burst.incr": "BIAS_INCR",
    "kind.read": "BIAS_READ",
    "kind.write": "BIAS_WRITE",
    # Abstract-model aliases emitted by python -m cgverif.regress.
    "op.read": "BIAS_READ",
    "op.write": "BIAS_WRITE",
}


def normalize_bins(payload: dict[str, Any]) -> dict[str, int]:
    bins = payload.get("bins", payload)
    if isinstance(bins, dict):
        out = {str(name): int(hits) for name, hits in bins.items()}
    elif isinstance(bins, list):
        out = {}
        for item in bins:
            if not isinstance(item, dict) or "name" not in item:
                raise ValueError("Each bins[] entry must contain a name")
            out[str(item["name"])] = int(item.get("hits", 0))
    else:
        raise ValueError("Coverage JSON must contain a bins object or list")

    negative = sorted(name for name, hits in out.items() if hits < 0)
    if negative:
        raise ValueError(
            "Coverage hit counts must be non-negative: " + ", ".join(negative)
        )
    return out


def build_bias(bins: dict[str, int], hit_threshold: int = 1) -> dict[str, Any]:
    if hit_threshold <= 0:
        raise ValueError("hit_threshold must be > 0")

    uncovered = sorted(name for name, hits in bins.items() if hits < hit_threshold)
    mapped = sorted(name for name in uncovered if name in BIAS_RULES)
    unmapped = sorted(name for name in uncovered if name not in BIAS_RULES)
    knobs = sorted({BIAS_RULES[name] for name in mapped})
    plusargs = [f"+{knob}=1" for knob in knobs]
    return {
        "uncovered_bins": uncovered,
        "mapped_uncovered_bins": mapped,
        "unmapped_uncovered_bins": unmapped,
        "bias_knobs": knobs,
        "plusargs": plusargs,
        "plusargs_string": " ".join(plusargs),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--threshold", type=int, default=1)
    args = parser.parse_args()

    if args.threshold <= 0:
        parser.error("--threshold must be > 0")

    payload = json.loads(args.input.read_text(encoding="utf-8"))
    bins = normalize_bins(payload)
    result = build_bias(bins, args.threshold)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")

    print("Uncovered:", ", ".join(result["uncovered_bins"]) or "none")
    print("Mapped holes:", ", ".join(result["mapped_uncovered_bins"]) or "none")
    print("Unmapped holes:", ", ".join(result["unmapped_uncovered_bins"]) or "none")
    print("Next-run plusargs:", result["plusargs_string"] or "none")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
