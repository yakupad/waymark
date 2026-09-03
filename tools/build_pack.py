#!/usr/bin/env python3
"""Waymark region-pack builder (spec Section 5, prompt P1).

Region-agnostic: everything country-specific comes from ``--config`` (a TOML file). The
pipeline turns Geofabrik OSM + TÜİK CSV + Wikidata JSON into a single SQLite ``*.pack``.

Usage:

    # real build (needs the input files listed in the config -- see tools/README.md)
    python3 -m tools.build_pack --config tools/config/tr.toml --out build/tr.pack

    # validation only, stops after the 81/973 count check
    python3 -m tools.build_pack --config tools/config/tr.toml --check

    # synthetic pack, no inputs required (for phase F2 / tests)
    python3 -m tools.build_pack --config tools/config/tr.toml --out build/tr.pack --fixture

Exit codes: 0 success, 1 pipeline/validation failure, 2 bad invocation / missing inputs.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Allow both `python3 -m tools.build_pack` and `python3 tools/build_pack.py`.
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from waymark_pack import config as config_mod  # type: ignore
    from waymark_pack import pipeline  # type: ignore
    from waymark_pack.extract import ExtractionError  # type: ignore
else:
    from .waymark_pack import config as config_mod
    from .waymark_pack import pipeline
    from .waymark_pack.extract import ExtractionError


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="build_pack", description=__doc__.splitlines()[0])
    parser.add_argument("--config", required=True, type=Path, help="region config TOML")
    parser.add_argument("--out", type=Path, help="output .pack path (required unless --check)")
    parser.add_argument("--fixture", action="store_true", help="build a synthetic pack, no inputs")
    parser.add_argument("--check", action="store_true", help="validate only, do not write a pack")
    parser.add_argument("--offline", action="store_true", help="skip Wikipedia summary fetching")
    parser.add_argument("--report", type=Path, help="also write the build report to this file")
    args = parser.parse_args(argv)

    if not args.check and not args.out:
        parser.error("--out is required unless --check is given")

    try:
        cfg = config_mod.load(args.config)
    except config_mod.ConfigError as exc:
        print(f"config error: {exc}", file=sys.stderr)
        return 2

    print(f"Region: {cfg.name_local} ({cfg.iso_code}), tiers: "
          f"{[f'{t.tier}:{t.label_local}' for t in cfg.tiers]}")

    try:
        if args.fixture:
            print("Building synthetic fixture pack …")
            rep = pipeline.run_fixture(cfg, args.out)
        else:
            rep = pipeline.run(
                cfg,
                None if args.check else args.out,
                check_only=args.check,
                offline=args.offline,
            )
    except ExtractionError as exc:
        print(f"\ninput/extraction error:\n  {exc}", file=sys.stderr)
        return 2
    except pipeline.PipelineError as exc:
        print(f"\npipeline failed:\n{exc}", file=sys.stderr)
        return 1
    except config_mod.ConfigError as exc:
        print(f"config error: {exc}", file=sys.stderr)
        return 2

    text = rep.as_text()
    print("\n" + text)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(text, encoding="utf-8")
        print(f"report written to {args.report}")

    if args.check:
        ok = rep.counts_ok
        print("validation:", "PASS" if ok else "FAIL")
        return 0 if ok else 1

    print(f"pack written to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
