public enum RemindersAuthorizationStatus:
    String,
    Sendable,
    Codable,
    Hashable
{
    case notDetermined = "not_determined"
    case restricted
    case denied
    case fullAccess = "full_access"
    case unknown
}

public struct RemindersAuthorizationRequestResult:
    Sendable,
    Codable,
    Hashable
{
    public let granted: Bool
    public let status: RemindersAuthorizationStatus

    public init(
        granted: Bool,
        status: RemindersAuthorizationStatus
    ) {
        self.granted = granted
        self.status = status
    }
}

public struct ReminderItem:
    Sendable,
    Codable,
    Hashable
{
    public let identifier: String?
    public let title: String
    public let isCompleted: Bool
    public let dueDate: String?
    public let completionDate: String?
    public let calendarTitle: String
    public let notes: String?
    public let priority: Int

    public init(
        identifier: String?,
        title: String,
        isCompleted: Bool,
        dueDate: String?,
        completionDate: String?,
        calendarTitle: String,
        notes: String?,
        priority: Int
    ) {
        self.identifier = identifier
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.completionDate = completionDate
        self.calendarTitle = calendarTitle
        self.notes = notes
        self.priority = priority
    }
}

public protocol AppleRemindersProvider: Sendable {
    func authorizationStatus() async
        -> RemindersAuthorizationStatus

    func requestFullAccess() async throws
        -> RemindersAuthorizationRequestResult

    func reminders(
        limit: Int
    ) async throws -> [ReminderItem]
}
