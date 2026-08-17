#!/usr/bin/env python3
"""Read MacBuddy perf.jsonl events for bench scripts."""
from __future__ import annotations

import json
import os
import sys
from typing import Iterable


def telemetry_path() -> str:
    return os.path.expanduser("~/Library/Application Support/MacBuddy/Telemetry/perf.jsonl")


def load_events(path: str | None = None) -> list[dict]:
    path = path or telemetry_path()
    if not os.path.exists(path):
        return []
    events: list[dict] = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            events.append(json.loads(line))
    return events


def last_duration_ms(kind: str, events: Iterable[dict] | None = None) -> float | None:
    rows = list(events) if events is not None else load_events()
    matched = [row for row in rows if row.get("kind") == kind]
    if not matched:
        return None
    return float(matched[-1]["durationMs"])


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: read_telemetry.py <kind>", file=sys.stderr)
        sys.exit(2)
    kind = sys.argv[1]
    value = last_duration_ms(kind)
    if value is None:
        print(-1)
        sys.exit(1)
    print(f"{value:.1f}")


if __name__ == "__main__":
    main()
