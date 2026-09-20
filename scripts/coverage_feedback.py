#!/usr/bin/env python3
"""Convert functional coverage holes into bias knobs for the next regression run."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


BIAS_RULES = {
    "len.long": "BIAS_LONG",
    "len.medium": "BIAS_MEDIUM",
    "burst.fixed": "BIAS_FIXED",
    "burst.incr": "BIAS_INCR",
    "kind.read": "BIAS_READ",
    "kind.write": "BIAS_WRITE",
    "size.byte": "BIAS_NARROW",
    "size.halfword": "BIAS_NARROW",
}


def normalize_bins(payload: dict[str, Any]) -> dict[str, int]:
    bins = payload.get("bins", payload)
    if isinstance(bins, dict):
        return {str(name): int(hits) for name, hits in bins.items()}

    if isinstance(bins, list):
        out: dict[str, int] = {}
        for item in bins:
            if not isinstance(item, dict) or "name" not in item:
                raise ValueError("Each bins[] entry must contain a name")
            out[str(item["name"])] = int(item.get("hits", 0))
        return out

    raise ValueError("Coverage JSON must contain a bins object or list")


def build_bias(bins: dict[str, int], hit_threshold: int = 1) -> dict[str, Any]:
    uncovered = sorted(name for name, hits in bins.items() if hits < hit_threshold)
    knobs = sorted({BIAS_RULES[name] for name in uncovered if name in BIAS_RULES})
    return {
        "uncovered_bins": uncovered,
        "bias_knobs": knobs,
        "plusargs": [f"+{knob}=1" for knob in knobs],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--threshold", type=int, default=1)
    args = parser.parse_args()

    payload = json.loads(args.input.read_text())
    bins = normalize_bins(payload)
    result = build_bias(bins, args.threshold)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")

    print("Uncovered:", ", ".join(result["uncovered_bins"]) or "none")
    print("Next-run plusargs:", " ".join(result["plusargs"]) or "none")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
