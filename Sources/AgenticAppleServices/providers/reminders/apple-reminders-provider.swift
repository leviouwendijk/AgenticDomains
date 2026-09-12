public protocol AppleRemindersProvider: Sendable {
    func authorizationStatus() async
        -> RemindersAuthorizationStatus

    func requestFullAccess() async throws
        -> RemindersAuthorizationRequestResult

    func reminders(
        limit: Int
    ) async throws -> [ReminderItem]

    func createReminder(
        _ creation: ReminderCreation
    ) async throws -> ReminderItem
}
