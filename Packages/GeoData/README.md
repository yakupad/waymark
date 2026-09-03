# GeoData

Offline spatial layer for Waymark (spec Section 6.1, phase F2). Reads a region pack
(`*.pack`, schema 5.3) and answers "what place is this coordinate in?". No UIKit, no
SwiftUI, no CoreLocation — pure and unit-testable in isolation.

## What's here

| File | Role | Spec |
|---|---|---|
| `Models.swift` | `Coordinate`, `Tier`, `PlaceRef`, `Place`, `PlaceResolution`, `Settlement`; the `GeoResolving` / `PlaceRepository` seams | §9, §6.3 |
| `PolygonDecoder.swift` | Decoder for the polygon binary format — a byte-for-byte contract with `tools/waymark_pack/polygon.py` | §5.4 |
| `PointInPolygon.swift` | Ray casting with inner-ring (enclave) support | §5.4, §7.6, §12.1 |
| `Haversine.swift` | Great-circle distance + bbox degree helpers | §7.6 |
| `GeometryCache.swift` | Fixed-capacity LRU for decoded rings (capacity 8) | §7.6 |
| `SQLiteGeoResolver.swift` | `GeoResolving` + `PlaceRepository` over GRDB; the §7.6 algorithm | §7.6, P3 |

## Dependency

[GRDB](https://github.com/groue/GRDB.swift) (locked decision, spec §17.3): mature
R\*Tree support, `Sendable`/concurrency friendly, one clean SPM dependency. The pack is
opened read-only; `DatabaseQueue` serialises access, so `SQLiteGeoResolver` is `Sendable`
and safe to share.

## Tests

```bash
swift test            # from Packages/GeoData
```

35 tests across 4 suites (Swift Testing). They run against `Tests/GeoDataTests/Fixtures/tr.pack`,
a synthetic pack — see that folder's README to regenerate.

## Resolution algorithm (spec 7.6)

1. R\*Tree bbox pre-filter → tier-1 candidates
2. read each candidate's geometry blob (LRU cache) → ray cast
3. for the matched tier-1, repeat over its children, and so on — **the number of tiers
   comes from `tier_label`, never from code** (spec K6)
4. nearest settlement via `settlement_rtree` + haversine

`resolve()` also attaches the nearest settlement and its distance; product thresholds
(spec 7.5 `settlementRadius`) are applied by the caller, not here.
