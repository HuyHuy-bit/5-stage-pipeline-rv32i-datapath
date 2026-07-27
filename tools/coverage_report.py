#!/usr/bin/env python3
"""Summarize a verilator_coverage merged .dat into a markdown functional
coverage report. Only the "user" page (our `cover property` points) is
reported — the "toggle"/"line" pages are Verilator's automatic bit-level
coverage, not the functional crosses this report is about.
"""
import re
import sys

# Fields are \x01-separated "code\x02value" pairs, e.g. \x01t\x02user\x01h\x02TOP.cpu.foo
LINE_RE = re.compile(r"^C '(.*)' (\d+)$")
FIELD_RE = re.compile(r"\x01(\w+)\x02([^\x01]*)")


def human(path: str) -> str:
    path = path.replace("__BRA__", "[").replace("__KET__", "]")
    path = path.replace("__DOT__", ".")
    return path.split(".", 1)[-1] if path.startswith("TOP.") else path


def main():
    datfile = sys.argv[1]
    points = {}
    with open(datfile) as f:
        for line in f:
            m = LINE_RE.match(line.rstrip("\n"))
            if not m:
                continue
            key, count = m.group(1), int(m.group(2))
            fields = dict(FIELD_RE.findall(key))
            if fields.get("t") != "user":
                continue
            name = human(fields.get("h", ""))
            points[name] = points.get(name, 0) + count

    total = len(points)
    hit = sum(1 for c in points.values() if c > 0)
    pct = 100.0 * hit / total if total else 0.0

    print("# Functional coverage report")
    print()
    print(f"**{hit}/{total} cover points hit ({pct:.1f}%)**, from the directed "
          "test suite run against a cache-enabled build (`make coverage`).")
    print()
    print("| Cover point | Hits |")
    print("|---|---|")
    for name in sorted(points):
        count = points[name]
        mark = "" if count > 0 else " **(unhit)**"
        print(f"| `{name}` | {count}{mark} |")

    unhit = [n for n, c in points.items() if c == 0]
    if unhit:
        print()
        print("## Unhit points")
        print()
        for n in sorted(unhit):
            print(f"- `{n}`")


if __name__ == "__main__":
    main()
