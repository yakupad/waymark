# LocationEngine

The presence pipeline for Waymark (spec §7, phases F3 / prompts P4–P5). Turns a stream
of location fixes into "you just entered X" events. Depends only on `GeoData` and
CoreLocation — no UIKit/SwiftUI, deterministically testable (spec 6.1).

## Pipeline

```
CLLocation ──► LocationProviding ──► SampleFilter (7.2) ──► GeoResolving (GeoData)
                                                                   │
                        PlaceResolution ──► one PresenceMachine per tier + settlement
                                                     (7.3–7.4, independent)
                                                                   │
                                                              [PlaceEvent]
```

| File | Role | Spec |
|---|---|---|
| `Models.swift` | `LocationSample`, `PlaceEvent`, `PresenceState`, `PresenceMachineKey` | §7.3, §9 |
| `PresenceTuning.swift` | every threshold in one struct; the debug menu mutates a copy | §7.5 |
| `SampleFilter.swift` | drop poor-accuracy / stale / impossible-jump fixes | §7.2 |
| `PresenceMachine.swift` | one independent state machine (unknown → candidate → confirmed → exiting) | §7.4 |
| `PresenceEngine.swift` | filter + resolve + step every machine; `Sendable`, lock-guarded | §7.3–7.6 |
| `TimeSource.swift` | injectable clock (`MutableTimeSource` for replay) | P4 |
| `LocationProviding.swift` | the CoreLocation seam + `TrackingConfiguration` (7.1) | §6.3, §7.1 |
| `CoreLocationProvider.swift` | production `CLLocationManager` wrapper (not unit-tested) | §6.1 |
| `GPXReplayer.swift` | parse a GPX trace, feed it to the engine — replay harness + debug-menu playback | §12.2, §10 |

## Key decisions

- **Timing is measured off fix timestamps**, not a wall clock, so a 10-hour route
  replays in milliseconds and identically every time. `TimeSource` is only for the
  "is this fix stale?" check (7.2).
- **The machine set grows from the data** (spec K6): a tier machine appears the first
  time a resolution reports that tier. A 3-tier country needs no code change.
- **Hysteresis is real**: entry thresholds (`confirmDwell*`) and exit thresholds
  (`exitBuffer*`) differ, so GPS jitter on a border cannot loop (spec 7.5).
- `settlementRadius` is applied here against `PlaceResolution.settlementDistanceMeters`;
  `regionCooldown` / `maxNotificationsPerHour` live in the tuning struct but are
  `Presence`'s job (F6).

## Tests

```bash
swift test        # from Packages/LocationEngine — 39 tests, 5 suites
```

`ReplayRouteTests` is a **disabled** skeleton carrying the spec 12.2 `istanbul-ordu`
province sequence and the five 12.3 routes. It needs real recorded GPX traces and the
real `tr.pack` — see `Tests/LocationEngineTests/Fixtures/gpx/README.md`. The synthetic
`GPXReplayerTests` prove the same wiring against the fixture pack today.
