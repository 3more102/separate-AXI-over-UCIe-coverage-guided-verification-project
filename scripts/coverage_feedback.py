#!/usr/bin/env python3
"""Convert functional-coverage hit counts into next-run stimulus biases."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict

DEFAULT_BINS = (
    "read",
    "write",
    "aw_before_w",
    "w_before_aw",
    "link_backpressure",
    "read_backpressure",
    "write_resp_error",
    "read_resp_error",
)


def load_counts(path: Path) -> Dict[str, int]:
    data = json.loads(path.read_text())
    counts = data.get("bins", data)
    result: Dict[str, int] = {}
    for name in DEFAULT_BINS:
        value = counts.get(name, 0)
        if not isinstance(value, int) or value < 0:
            raise ValueError(f"coverage bin {name!r} must be a non-negative integer")
        result[name] = value
    return result


def inverse_frequency_weights(
    counts: Dict[str, int], floor: int = 1, scale: int = 100
) -> Dict[str, int]:
    if floor < 1 or scale < 1:
        raise ValueError("floor and scale must both be >= 1")
    return {
        name: max(floor, round(scale / (hits + 1)))
        for name, hits in counts.items()
    }


def derive_knobs(weights: Dict[str, int]) -> Dict[str, int]:
    return {
        "BIAS_READ": weights["read"],
        "BIAS_WRITE": weights["write"],
        "BIAS_ERROR_ADDR": max(
            weights["write_resp_error"], weights["read_resp_error"]
        ),
        "BIAS_BACKPRESSURE": max(
            weights["link_backpressure"], weights["read_backpressure"]
        ),
        "BIAS_AW_FIRST": weights["aw_before_w"],
        "BIAS_W_FIRST": weights["w_before_aw"],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--plusargs", type=Path)
    args = parser.parse_args()

    counts = load_counts(args.input)
    weights = inverse_frequency_weights(counts)
    knobs = derive_knobs(weights)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps({"counts": counts, "weights": weights, "knobs": knobs}, indent=2)
        + "\n"
    )

    if args.plusargs:
        args.plusargs.parent.mkdir(parents=True, exist_ok=True)
        args.plusargs.write_text(
            "\n".join(f"+{key}={value}" for key, value in knobs.items()) + "\n"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
