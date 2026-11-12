import Foundation

public enum TimerMath {
    public static let maxMinutes = 720

    public static func elapsedMinutes(from start: Date, to now: Date) -> Int {
        let seconds = max(0, now.timeIntervalSince(start))
        let minutes = Int((seconds / 60).rounded(.up))
        return min(max(minutes, 1), maxMinutes)
    }
}
