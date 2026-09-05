public enum CalendarAuthorizationStatus:
    String,
    Sendable,
    Codable,
    Hashable
{
    case notDetermined = "not_determined"
    case restricted
    case denied
    case fullAccess = "full_access"
    case writeOnly = "write_only"
    case unknown
}

public struct CalendarAuthorizationRequestResult:
    Sendable,
    Codable,
    Hashable
{
    public let granted: Bool
    public let status: CalendarAuthorizationStatus

    public init(
        granted: Bool,
        status: CalendarAuthorizationStatus
    ) {
        self.granted = granted
        self.status = status
    }
}

public struct CalendarEventQuery:
    Sendable,
    Codable,
    Hashable
{
    public let startDate: String
    public let endDate: String
    public let limit: Int

    public init(
        startDate: String,
        endDate: String,
        limit: Int
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.limit = limit
    }
}

public struct CalendarEvent:
    Sendable,
    Codable,
    Hashable
{
    public let identifier: String?
    public let title: String
    public let startDate: String
    public let endDate: String
    public let isAllDay: Bool
    public let calendarTitle: String
    public let location: String?
    public let notes: String?

    public init(
        identifier: String?,
        title: String,
        startDate: String,
        endDate: String,
        isAllDay: Bool,
        calendarTitle: String,
        location: String?,
        notes: String?
    ) {
        self.identifier = identifier
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarTitle = calendarTitle
        self.location = location
        self.notes = notes
    }
}

public protocol AppleCalendarProvider: Sendable {
    func authorizationStatus() async -> CalendarAuthorizationStatus

    func requestFullAccess() async throws
        -> CalendarAuthorizationRequestResult

    func events(
        _ query: CalendarEventQuery
    ) async throws -> [CalendarEvent]
}
