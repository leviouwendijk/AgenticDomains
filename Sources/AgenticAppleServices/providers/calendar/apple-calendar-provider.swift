public protocol AppleCalendarProvider: Sendable {
    func authorizationStatus() async -> CalendarAuthorizationStatus

    func requestFullAccess() async throws
        -> CalendarAuthorizationRequestResult

    func events(
        _ query: CalendarEventQuery
    ) async throws -> [CalendarEvent]
}
