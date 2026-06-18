import Foundation

enum TimelineTrim {
    enum Edge {
        case start
        case end
    }

    enum DragTarget: Equatable {
        case start
        case end
        case playhead
    }

    static let minimumDuration = 0.1

    static func clampedRange(start: Double, end: Double, duration: Double) -> (start: Double, end: Double) {
        let duration = max(0, duration)
        guard duration > 0 else { return (0, 0) }

        let minDuration = min(minimumDuration, duration)
        var clampedStart = clamp(start, lower: 0, upper: duration)
        var clampedEnd = clamp(end > 0 ? end : duration, lower: 0, upper: duration)

        if clampedEnd <= clampedStart {
            clampedEnd = duration
        }

        if clampedEnd - clampedStart < minDuration {
            if clampedStart + minDuration <= duration {
                clampedEnd = clampedStart + minDuration
            } else {
                clampedStart = max(0, duration - minDuration)
                clampedEnd = duration
            }
        }

        return (clampedStart, clampedEnd)
    }

    static func updatedRange(
        moving edge: Edge,
        to proposedTime: Double,
        start: Double,
        end: Double,
        duration: Double
    ) -> (start: Double, end: Double) {
        let duration = max(0, duration)
        guard duration > 0 else { return (0, 0) }

        let minDuration = min(minimumDuration, duration)
        switch edge {
        case .start:
            let clampedEnd = clamp(end, lower: minDuration, upper: duration)
            let clampedStart = clamp(proposedTime, lower: 0, upper: clampedEnd - minDuration)
            return (clampedStart, clampedEnd)
        case .end:
            let clampedStart = clamp(start, lower: 0, upper: max(0, duration - minDuration))
            let clampedEnd = clamp(proposedTime, lower: clampedStart + minDuration, upper: duration)
            return (clampedStart, clampedEnd)
        }
    }

    static func clampedTime(_ seconds: Double, start: Double, end: Double, duration: Double) -> Double {
        let range = clampedRange(start: start, end: end, duration: duration)
        return clamp(seconds, lower: range.start, upper: range.end)
    }

    static func time(forFraction fraction: Double, duration: Double) -> Double {
        clamp(fraction, lower: 0, upper: 1) * max(0, duration)
    }

    static func fraction(forTime seconds: Double, duration: Double) -> Double {
        guard duration > 0 else { return 0 }
        return clamp(seconds / duration, lower: 0, upper: 1)
    }

    static func fraction(forX x: Double, width: Double) -> Double {
        guard width > 0 else { return 0 }
        return clamp(x / width, lower: 0, upper: 1)
    }

    static func playheadFraction(
        forTime seconds: Double,
        start: Double,
        end: Double,
        duration: Double
    ) -> Double {
        fraction(forTime: clampedTime(seconds, start: start, end: end, duration: duration), duration: duration)
    }

    static func thumbnailTileWidth(totalWidth: Double, count: Int, spacing: Double) -> Double {
        guard count > 0 else { return 0 }
        let availableWidth = max(0, totalWidth - spacing * Double(max(0, count - 1)))
        return max(1, availableWidth / Double(count))
    }

    static func dragTarget(
        x: Double,
        startX: Double,
        endX: Double,
        playheadX: Double,
        handleHitWidth: Double,
        playheadHitWidth: Double
    ) -> DragTarget? {
        if abs(x - startX) <= handleHitWidth / 2 {
            return .start
        }
        if abs(x - endX) <= handleHitWidth / 2 {
            return .end
        }
        if abs(x - playheadX) <= playheadHitWidth / 2 {
            return .playhead
        }
        return nil
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
