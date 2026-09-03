# Presence

Routes presence events to the Live Activity and push channels (spec §8, phase F4 /
prompt P6). Pure routing/gating logic is unit-tested; the ActivityKit and
UserNotifications wrappers are thin and device-verified.

| File | Role | Spec |
|---|---|---|
| `PresencePolicy.swift` | the event → surface matrix; `NotificationSensitivity` (default `.tier1`) | 8.1 |
| `NotificationGate.swift` | push brakes: 24 h cooldown per place, ≤ 6/hour ceiling, quiet hours | 7.5, 8.4 |
| `UpdateCoalescer.swift` | ≤ 1 Live Activity update per 60 s; events inside the window merge | 8.2 |
| `NotificationCopy.swift` | title/body ("Merzifon'dasın" · "Amasya · 52.000 nüfus"); Turkish locative with vowel harmony (R6) | 8.3 |
| `Surfaces.swift` | `ActivitySurface` / `NotificationSurface` seams, `LiveActivityState`, `PlaceNotification`, `DeepLink` | 8 |
| `PresenceCoordinator.swift` | `actor` implementing `PresencePresenting` (spec 6.3); orchestrates the above | 8 |
| `UserNotificationSurface.swift` | `UNUserNotificationCenter` wrapper (not unit-tested) | 8.3 |
| `LiveActivitySurface.swift` | ActivityKit `Activity` lifecycle + `WaymarkActivityAttributes` (iOS only, not unit-tested) | 8.2 |

## What's done vs. remaining

**Done & tested (137 assertions across 6 suites):** sensitivity routing, cooldown, the
sliding-hour rate limit, quiet hours (wrapping and non-wrapping), 60 s coalescing, the
trip lifecycle (`startActivity` → `update` → `endActivity`), Turkish locative copy, deep
links.

**Remaining (device / app work, F6–F8):**

- the Live Activity **widget UI** — the lock-screen view and the four Dynamic Island
  states — needs a Widget Extension target. `WaymarkActivityAttributes.ContentState` is
  the contract it renders.
- `NSSupportsLiveActivities` in Info.plist, the notification-permission prompt flow
- on-device verification of the actual notification / Live Activity delivery (spec F4
  output: "Cihazda çalışan bildirim akışı")

## Tests

```bash
swift test        # from Packages/Presence — 37 tests, 6 suites
```
