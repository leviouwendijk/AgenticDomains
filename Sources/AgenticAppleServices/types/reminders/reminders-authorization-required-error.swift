import Foundation

public struct RemindersAuthorizationRequiredError:
    Error,
    Sendable,
    LocalizedError
{
    public let status: RemindersAuthorizationStatus

    public init(
        status: RemindersAuthorizationStatus
    ) {
        self.status = status
    }

    public var errorDescription: String? {
        "Creating a reminder requires full Reminders access; current status is \(status.rawValue)."
    }
}
