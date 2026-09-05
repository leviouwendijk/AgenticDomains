import EventKit
import Foundation

public actor EventKitCalendarProvider:
    AppleCalendarProvider
{
    private let eventStore: EKEventStore

    public init(
        eventStore: EKEventStore = .init()
    ) {
        self.eventStore = eventStore
    }

    public func authorizationStatus()
        -> CalendarAuthorizationStatus
    {
        Self.authorizationStatus(
            EKEventStore.authorizationStatus(
                for: .event
            )
        )
    }

    public func requestFullAccess() async throws
        -> CalendarAuthorizationRequestResult
    {
        guard #available(macOS 14.0, *) else {
            throw EventKitCalendarProviderError
                .fullAccessRequiresMacOS14
        }

        let granted = try await eventStore
            .requestFullAccessToEvents()
        let status = authorizationStatus()

        return .init(
            granted: granted,
            status: status
        )
    }

    public func events(
        _ query: CalendarEventQuery
    ) async throws -> [CalendarEvent] {
        guard let startDate = Self.date(
            from: query.startDate
        ) else {
            throw EventKitCalendarProviderError
                .invalidStartDate(query.startDate)
        }

        guard let endDate = Self.date(
            from: query.endDate
        ) else {
            throw EventKitCalendarProviderError
                .invalidEndDate(query.endDate)
        }

        guard endDate > startDate else {
            throw EventKitCalendarProviderError
                .invalidDateRange
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        let limit = min(
            max(query.limit, 1),
            200
        )

        return Array(
            eventStore.events(
                matching: predicate
            )
            .sorted {
                $0.startDate < $1.startDate
            }
            .prefix(limit)
            .map { event in
                CalendarEvent(
                    identifier: event.eventIdentifier,
                    title: event.title ?? "",
                    startDate: Self.string(
                        from: event.startDate
                    ),
                    endDate: Self.string(
                        from: event.endDate
                    ),
                    isAllDay: event.isAllDay,
                    calendarTitle: event.calendar.title,
                    location: event.location,
                    notes: event.notes
                )
            }
        )
    }
}

private extension EventKitCalendarProvider {
    static func date(
        from value: String
    ) -> Date? {
        let formatter = ISO8601DateFormatter()

        if let date = formatter.date(
            from: value
        ) {
            return date
        }

        formatter.formatOptions.insert(
            .withFractionalSeconds
        )

        return formatter.date(
            from: value
        )
    }

    static func string(
        from date: Date
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(
            .withFractionalSeconds
        )
        return formatter.string(
            from: date
        )
    }

    static func authorizationStatus(
        _ status: EKAuthorizationStatus
    ) -> CalendarAuthorizationStatus {
        if #available(macOS 14.0, *) {
            switch status {
            case .notDetermined:
                return .notDetermined
            case .restricted:
                return .restricted
            case .denied:
                return .denied
            case .fullAccess:
                return .fullAccess
            case .writeOnly:
                return .writeOnly
            case .authorized:
                return .fullAccess
            @unknown default:
                return .unknown
            }
        }

        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .fullAccess
        default:
            return .unknown
        }
    }
}

public enum EventKitCalendarProviderError:
    Error,
    Sendable,
    LocalizedError
{
    case fullAccessRequiresMacOS14
    case invalidStartDate(String)
    case invalidEndDate(String)
    case invalidDateRange

    public var errorDescription: String? {
        switch self {
        case .fullAccessRequiresMacOS14:
            return "Full EventKit calendar access requires macOS 14 or newer."

        case .invalidStartDate(let value):
            return "Invalid ISO 8601 calendar start date: \(value)"

        case .invalidEndDate(let value):
            return "Invalid ISO 8601 calendar end date: \(value)"

        case .invalidDateRange:
            return "Calendar event query end date must be later than its start date."
        }
    }
}
