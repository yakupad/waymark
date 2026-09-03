# GPX fixtures

## Synthetic (committed, used by the active tests)

Hand-authored traces over the **synthetic** `tr.pack` geometry (province A / B, district
C1 with the C2 enclave). Fix spacing keeps implied speed under the 60 m/s filter
(spec 7.2).

| File | Exercises |
|---|---|
| `synthetic-cross-provinces.gpx` | A→B crossing: province events `[1, 2]`, district events `[3, 5]` |
| `synthetic-boundary-oscillation.gpx` | riding the A/B border with a ~520 m wobble → one province event, no flip-flop (hysteresis, spec 7.5) |

## Recorded routes (spec 12.3 — not yet captured)

`ReplayRouteTests` is a disabled skeleton until these exist. Each needs a real GPS trace
**and** the real `tr.pack` (see `tools/README.md`). Drop the file here, point the test's
resolver at the real pack, and remove `.disabled`.

| File | Purpose (spec 12.3) |
|---|---|
| `istanbul-ordu.gpx` | main scenario, long distance — province sequence in spec 12.2 |
| `boundary-oscillation.gpx` | a real border-hugging route — hysteresis |
| `village-cluster.gpx` | dense villages — notification frequency |
| `urban-slow.gpx` | city crawl, low speed — false-trigger resistance |
| `poor-signal.gpx` | location gaps — interruption resilience |

Record with any GPX logger during an actual drive, or synthesise from a routing engine
polyline with realistic timestamps.
