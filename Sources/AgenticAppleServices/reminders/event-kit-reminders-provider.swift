import EventKit
import Foundation

public actor EventKitRemindersProvider:
    AppleRemindersProvider
{
    private let eventStore: EKEventStore

    public init(
        eventStore: EKEventStore = .init()
    ) {
        self.eventStore = eventStore
    }

    public func authorizationStatus()
        -> RemindersAuthorizationStatus
    {
        Self.authorizationStatus(
            EKEventStore.authorizationStatus(
                for: .reminder
            )
        )
    }

    public func requestFullAccess() async throws
        -> RemindersAuthorizationRequestResult
    {
        guard #available(macOS 14.0, *) else {
            throw EventKitRemindersProviderError
                .fullAccessRequiresMacOS14
        }

        let granted = try await eventStore
            .requestFullAccessToReminders()
        let status = authorizationStatus()

        return .init(
            granted: granted,
            status: status
        )
    }

    public func reminders(
        limit: Int
    ) async throws -> [ReminderItem] {
        let predicate = eventStore
            .predicateForReminders(
                in: nil
            )
        let limit = min(
            max(limit, 1),
            200
        )

        let items: [ReminderItem] =
            await withCheckedContinuation {
                continuation in

                _ = eventStore.fetchReminders(
                    matching: predicate
                ) { reminders in
                    continuation.resume(
                        returning:
                            (reminders ?? [])
                                .map(Self.item)
                    )
                }
            }

        return Array(
            items
                .sorted(by: Self.lessThan)
                .prefix(limit)
        )
    }
}

private extension EventKitRemindersProvider {
    static func authorizationStatus(
        _ status: EKAuthorizationStatus
    ) -> RemindersAuthorizationStatus {
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
            case .authorized:
                return .fullAccess
            case .writeOnly:
                return .unknown
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

    static func item(
        _ reminder: EKReminder
    ) -> ReminderItem {
        .init(
            identifier:
                reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            isCompleted: reminder.isCompleted,
            dueDate:
                reminder.dueDateComponents
                    .flatMap {
                        Calendar.autoupdatingCurrent
                            .date(from: $0)
                    }
                    .map(string),
            completionDate:
                reminder.completionDate
                    .map(string),
            calendarTitle:
                reminder.calendar.title,
            notes: reminder.notes,
            priority: reminder.priority
        )
    }

    static func lessThan(
        _ lhs: ReminderItem,
        _ rhs: ReminderItem
    ) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }

        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?):
            if left != right {
                return left < right
            }

        case (.some, .none):
            return true

        case (.none, .some):
            return false

        case (.none, .none):
            break
        }

        return lhs.title.localizedCaseInsensitiveCompare(
            rhs.title
        ) == .orderedAscending
    }

    static func string(
        _ date: Date
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(
            .withFractionalSeconds
        )
        return formatter.string(
            from: date
        )
    }
}

public enum EventKitRemindersProviderError:
    Error,
    Sendable,
    LocalizedError
{
    case fullAccessRequiresMacOS14

    public var errorDescription: String? {
        switch self {
        case .fullAccessRequiresMacOS14:
            return "Full EventKit reminders access requires macOS 14 or newer."
        }
    }
}
