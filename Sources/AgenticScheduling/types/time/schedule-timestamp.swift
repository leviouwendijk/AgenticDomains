import Foundation

/// ISO 8601 parsing and rendering at the tool boundary.
public enum ScheduleTimestamp {
    public enum Failure: Error, Sendable, LocalizedError {
        case invalid(field: String, value: String)
        case emptyWindow(start: String, end: String)

        public var errorDescription: String? {
            switch self {
            case .invalid(let field, let value):
                return "\(field) is not an ISO 8601 timestamp with offset: \(value)"
            case .emptyWindow(let start, let end):
                return "The window must end after it starts: \(start) ..< \(end)"
            }
        }
    }

    public static func parse(_ value: String, field: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions.insert(.withFractionalSeconds)
        if let date = formatter.date(from: value) {
            return date
        }
        throw Failure.invalid(field: field, value: value)
    }

    public static func window(start: String, end: String) throws -> ScheduleInterval {
        let from = try parse(start, field: "window_start")
        let to = try parse(end, field: "window_end")
        guard let interval = try? ScheduleInterval(start: from, end: to) else {
            throw Failure.emptyWindow(start: start, end: end)
        }
        return interval
    }

    /// Renders with the zone's offset, so results read in local time.
    public static func render(_ date: Date, in zone: ScheduleTimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = zone.timeZone
        return formatter.string(from: date)
    }
}
