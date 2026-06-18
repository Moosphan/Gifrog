import Foundation

@main
struct TimelineTrimVerification {
    static func main() {
        let duration = 10.0

        let leftClamp = TimelineTrim.updatedRange(
            moving: .start,
            to: 9.95,
            start: 2.0,
            end: 8.0,
            duration: duration
        )
        expectEqual(leftClamp.start, 7.9, "left handle should stay at least 0.1s before end")
        expectEqual(leftClamp.end, 8.0, "left handle should not move end")

        let rightClamp = TimelineTrim.updatedRange(
            moving: .end,
            to: 2.02,
            start: 4.0,
            end: 8.0,
            duration: duration
        )
        expectEqual(rightClamp.start, 4.0, "right handle should not move start")
        expectEqual(rightClamp.end, 4.1, "right handle should stay at least 0.1s after start")

        let normalized = TimelineTrim.clampedRange(start: -4, end: 0, duration: duration)
        expectEqual(normalized.start, 0, "range start should clamp to beginning")
        expectEqual(normalized.end, duration, "empty end should default to full duration")

        expectEqual(
            TimelineTrim.clampedTime(-1, start: 2, end: 7, duration: duration),
            2,
            "playback seek should not go before trim start"
        )
        expectEqual(
            TimelineTrim.clampedTime(9, start: 2, end: 7, duration: duration),
            7,
            "playback seek should not go after trim end"
        )
        expectEqual(
            TimelineTrim.time(forFraction: 1.4, duration: duration),
            duration,
            "timeline fraction should clamp above 1"
        )
        expectEqual(
            TimelineTrim.playheadFraction(forTime: 9, start: 2, end: 7, duration: duration),
            0.7,
            "playhead marker should clamp to trim end"
        )
        expectEqual(
            TimelineTrim.thumbnailTileWidth(totalWidth: 1199, count: 4, spacing: 1),
            299,
            "thumbnail tile width should account for inter-tile spacing"
        )

        let tiny = TimelineTrim.updatedRange(moving: .end, to: 0.01, start: 0, end: 0.03, duration: 0.05)
        expectEqual(tiny.start, 0, "tiny duration start should remain valid")
        expectEqual(tiny.end, 0.05, "tiny duration should allow full available span")

        let leftTarget = TimelineTrim.dragTarget(
            x: 6,
            startX: 0,
            endX: 900,
            playheadX: 0,
            handleHitWidth: 30,
            playheadHitWidth: 22
        )
        expectEqual(leftTarget, .start, "left trim handle should win when it overlaps the playhead")

        let rightTarget = TimelineTrim.dragTarget(
            x: 894,
            startX: 0,
            endX: 900,
            playheadX: 0,
            handleHitWidth: 30,
            playheadHitWidth: 22
        )
        expectEqual(rightTarget, .end, "right trim handle should be draggable at the timeline edge")
    }

    private static func expectEqual(_ actual: Double, _ expected: Double, _ message: String, tolerance: Double = 0.0001) {
        if abs(actual - expected) > tolerance {
            fputs("FAIL: \(message). expected \(expected), got \(actual)\n", stderr)
            exit(1)
        }
    }

    private static func expectEqual(
        _ actual: TimelineTrim.DragTarget?,
        _ expected: TimelineTrim.DragTarget,
        _ message: String
    ) {
        if actual != expected {
            fputs("FAIL: \(message). expected \(expected), got \(String(describing: actual))\n", stderr)
            exit(1)
        }
    }
}
