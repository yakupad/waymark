import Foundation
import Testing
@testable import LocationEngine

@Suite("TravelRun")
struct TravelRunTests {

    @Test("A stretch of driving sets travellingSince to when it began")
    func drivingStarts() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        var run = TravelRun()
        run.ingest(.automotive, at: t0)
        run.ingest(.automotive, at: t0 + 60)
        #expect(run.travellingSince == t0)
    }

    @Test("A red-light stationary blip inside the grace window keeps the run")
    func stationaryBlipKeepsRun() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        var run = TravelRun()
        run.ingest(.automotive, at: t0)
        run.ingest(.stationary, at: t0 + 90)      // 90s stop < 3min grace
        run.ingest(.automotive, at: t0 + 150)
        #expect(run.travellingSince == t0)
    }

    @Test("A long stationary stretch ends the run")
    func longStationaryEndsRun() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        var run = TravelRun()
        run.ingest(.automotive, at: t0)
        run.ingest(.stationary, at: t0 + 5 * 60)  // > 3min grace
        #expect(run.travellingSince == nil)
    }

    @Test("Walking ends the run — the traveller got out")
    func walkingEndsRun() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        var run = TravelRun()
        run.ingest(.cycling, at: t0)
        run.ingest(.walking, at: t0 + 60)
        #expect(run.travellingSince == nil)
    }

    @Test("Replaying history yields the same run")
    func replayHistory() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        let run = TravelRun.run(over: [
            (.stationary, t0),
            (.automotive, t0 + 60),
            (.automotive, t0 + 600),
        ])
        #expect(run.travellingSince == t0 + 60)
    }
}

@Suite("TravelNudgePolicy")
struct TravelNudgePolicyTests {
    let policy = TravelNudgePolicy()
    let now = Date(timeIntervalSince1970: 100_000)

    @Test("Nudges after sustained travel with no active trip")
    func nudges() {
        #expect(policy.shouldNudge(
            travellingSince: now - 5 * 60, isTripActive: false,
            lastNudge: nil, lastTripEnd: nil, now: now
        ))
    }

    @Test("Does not nudge before the sustained threshold")
    func tooEarly() {
        #expect(!policy.shouldNudge(
            travellingSince: now - 60, isTripActive: false,
            lastNudge: nil, lastTripEnd: nil, now: now
        ))
    }

    @Test("Does not nudge while a trip is running")
    func tripActive() {
        #expect(!policy.shouldNudge(
            travellingSince: now - 30 * 60, isTripActive: true,
            lastNudge: nil, lastTripEnd: nil, now: now
        ))
    }

    @Test("Respects the cooldown after a recent nudge")
    func cooldown() {
        #expect(!policy.shouldNudge(
            travellingSince: now - 10 * 60, isTripActive: false,
            lastNudge: now - 20 * 60, lastTripEnd: nil, now: now
        ))
    }

    @Test("Stays quiet right after a trip the user ended")
    func postTripQuiet() {
        #expect(!policy.shouldNudge(
            travellingSince: now - 10 * 60, isTripActive: false,
            lastNudge: nil, lastTripEnd: now - 5 * 60, now: now
        ))
    }

    @Test("Nudges again once the cooldown has elapsed")
    func afterCooldown() {
        #expect(policy.shouldNudge(
            travellingSince: now - 10 * 60, isTripActive: false,
            lastNudge: now - 2 * 60 * 60, lastTripEnd: nil, now: now
        ))
    }
}
