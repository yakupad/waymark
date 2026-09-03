# TripKit

Route-trace engine for Waymark (spec 7.7, phase F5 / prompt P7). Pure Swift — no MapKit,
no SwiftData. Records the polyline during a trip, simplifies it, and serialises it to a
single blob. Trip persistence and history (SwiftData) arrive in F6.

| File | Role | Spec |
|---|---|---|
| `RouteModels.swift` | `RouteSegment`, `RouteTrace`, `RouteTrace.trimmed(by:)` | §9, 7.7 |
| `RouteRecorder.swift` | in-memory buffer, 200-point flush signal, 2 km / 5 min segmentation, finish → simplify | 7.7 |
| `DouglasPeucker.swift` | RDP line simplification at 20 m; keeps first/last | 7.7 step 3 |
| `RouteTrimmer.swift` | endpoint trimming for share images (R8) | 7.7 |
| `RouteBlob.swift` | single-`Data` serialisation: spec 5.4 `int32 × 1e6` coords + segment boundaries; throws on corruption | 7.7 step 4 |

## Notes

- **Detection and recording are separate** (7.7): the recorder just consumes the same
  filtered fixes; turning the trace off does not affect presence detection.
- Segments model gaps (tunnels, no-signal): a > 2 km or > 5 min jump between consecutive
  fixes starts a new segment, so a straight line is never drawn across the Bolu tunnel.
- `trimmed(by:)` removes the first/last N metres of polyline for share images so home is
  not disclosed (R8). `meters <= 0` is a no-op; a trim past the route length → empty.
- Blob budget: a 750 km trip simplifies to ~1 500 points ≈ 12 KB (3 + 20 + 1500·8).

## Tests

```bash
swift test        # from Packages/TripKit — 33 tests, 4 suites
```
