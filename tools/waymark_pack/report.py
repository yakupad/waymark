"""Build reports (spec 5.2 steps 2-3, 7 and prompt P1).

A build produces, alongside the pack:

* count validation (81 tier-1 / 973 tier-2 for TR) — a mismatch is a hard error
* skipped records (invalid ``admin_level`` like 88) — skipped, never fatal
* name collisions (28 expected for TR) — reported, not an error
* suspicious tier-2 parent assignments (overlap < 50%)
* per-language content coverage
* per-table size of the finished pack
"""

from __future__ import annotations

import io
from dataclasses import dataclass, field


@dataclass
class TierCount:
    tier: int
    expected: int
    actual: int
    tolerance: float = 0.0

    @property
    def allowed_delta(self) -> int:
        return max(0, round(self.expected * self.tolerance))

    @property
    def ok(self) -> bool:
        return abs(self.actual - self.expected) <= self.allowed_delta


@dataclass
class BuildReport:
    region_iso: str
    tier_counts: list[TierCount] = field(default_factory=list)
    skipped_records: list[str] = field(default_factory=list)      # invalid admin_level etc.
    name_collisions: dict[str, list[str]] = field(default_factory=dict)
    orphan_tier1: list[str] = field(default_factory=list)          # tier-1 with no children
    suspicious_parents: list[str] = field(default_factory=list)    # low-overlap tier-2
    unclosed_rings: list[str] = field(default_factory=list)
    filter_tag_count: dict[int, int] = field(default_factory=dict)  # tier -> tag-based count
    filter_geom_count: dict[int, int] = field(default_factory=dict)  # tier -> geometry count
    coverage: list = field(default_factory=list)                   # content.CoverageReport
    table_bytes: dict[str, int] = field(default_factory=dict)
    build_hash: str = ""

    @property
    def counts_ok(self) -> bool:
        return all(tc.ok for tc in self.tier_counts)

    def as_text(self) -> str:
        buf = io.StringIO()
        w = buf.write
        w(f"=== Waymark pack build report — {self.region_iso} ===\n\n")

        w("Unit counts\n")
        for tc in self.tier_counts:
            mark = "OK " if tc.ok else "FAIL"
            tol = f" (±{tc.allowed_delta})" if tc.allowed_delta else ""
            w(f"  [{mark}] tier {tc.tier}: expected {tc.expected}{tol}, got {tc.actual}\n")

        if self.filter_tag_count or self.filter_geom_count:
            w("\nCountry filter (tag-based vs geometry-based)\n")
            tiers = sorted(set(self.filter_tag_count) | set(self.filter_geom_count))
            for t in tiers:
                w(
                    f"  tier {t}: tag={self.filter_tag_count.get(t, '-')} "
                    f"geom={self.filter_geom_count.get(t, '-')}\n"
                )

        w(f"\nSkipped records: {len(self.skipped_records)}\n")
        for line in self.skipped_records[:20]:
            w(f"  - {line}\n")
        if len(self.skipped_records) > 20:
            w(f"  … and {len(self.skipped_records) - 20} more\n")

        w(f"\nName collisions: {len(self.name_collisions)} (28 expected for TR)\n")
        for key, names in list(self.name_collisions.items())[:10]:
            w(f"  - {key}: {', '.join(names)}\n")

        if self.orphan_tier1:
            w(f"\nTier-1 units with no children: {len(self.orphan_tier1)}\n")
            for name in self.orphan_tier1:
                w(f"  - {name}\n")

        if self.suspicious_parents:
            w(f"\nSuspicious tier-2 parent assignments (< threshold overlap): "
              f"{len(self.suspicious_parents)}\n")
            for line in self.suspicious_parents[:20]:
                w(f"  - {line}\n")

        if self.unclosed_rings:
            w(f"\nUnclosed rings: {len(self.unclosed_rings)}\n")

        if self.coverage:
            w("\nContent coverage\n")
            for c in self.coverage:
                flag = "  <-- below min_coverage_warn (R13)" if c.ratio < _WARN.get(c.lang, 0) else ""
                w(f"  {c.lang}: {c.have}/{c.total} ({c.ratio:.0%}){flag}\n")

        if self.table_bytes:
            w("\nPack size by table\n")
            for name, size in sorted(self.table_bytes.items(), key=lambda kv: -kv[1]):
                w(f"  {name:<20} {size / 1024:>10.1f} KB\n")
            total = sum(self.table_bytes.values())
            w(f"  {'TOTAL':<20} {total / 1024:>10.1f} KB ({total / 1024 / 1024:.2f} MB)\n")

        if self.build_hash:
            w(f"\nbuild_hash: {self.build_hash}\n")
        return buf.getvalue()


# populated by pipeline before rendering (min_coverage_warn per lang)
_WARN: dict[str, float] = {}


def set_coverage_threshold(languages: list[str], threshold: float) -> None:
    _WARN.clear()
    _WARN.update({lang: threshold for lang in languages})
