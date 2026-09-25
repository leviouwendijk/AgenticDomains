import Agentic
import Macros
import Schema
import Workspace

public extension AppleServices.Tools {
    @Tool("reminders_authorization_status")
    struct ReadRemindersAuthorizationStatus {
        @JSONSchema
        public struct Input:
            Codable,
            Sendable,
            Hashable
        {
            public init() {}
        }

        public typealias Output = RemindersAuthorizationStatus

        public static let purpose =
            "Observe the current macOS Reminders authorization status without requesting permission."
        public static let risk: ActionRisk = .observe

        private let provider: any AppleRemindersProvider

        public init(
            provider: any AppleRemindersProvider
        ) {
            self.provider = provider
        }

        public func call(
            _ input: Input,
            workspace _: WorkspaceContext?
        ) async throws -> Output {
            _ = input
            return await provider.authorizationStatus()
        }
    }

    @Tool("reminders_request_full_access")
    struct RequestRemindersFullAccess {
        @JSONSchema
        public struct Input:
            Codable,
            Sendable,
            Hashable
        {
            public init() {}
        }

        public typealias Output = RemindersAuthorizationRequestResult

        public static let purpose =
            "Request full access to the user's reminders through the macOS EventKit privacy permission flow."
        public static let risk: ActionRisk = .boundedmutate

        private let provider: any AppleRemindersProvider

        public init(
            provider: any AppleRemindersProvider
        ) {
            self.provider = provider
        }

        public func call(
            _ input: Input,
            workspace _: WorkspaceContext?
        ) async throws -> Output {
            _ = input
            return try await provider.requestFullAccess()
        }
    }

    @Tool("reminders_create")
    struct CreateReminder {
        public typealias Input = ReminderCreation
        public typealias Output = ReminderItem

        public static let purpose =
            "Create exactly one reminder in an explicit reminder list or the configured default reminders list."
        public static let risk: ActionRisk = .boundedmutate

        private let provider: any AppleRemindersProvider

        public init(
            provider: any AppleRemindersProvider
        ) {
            self.provider = provider
        }

        public func preflight(
            _ input: Input,
            workspace _: WorkspaceContext?
        ) async throws -> ToolPreflight {
            let destination =
                input.listTitle ?? "default reminders list"

            return ToolPreflight(
                tool: Self.definition.identifier,
                risk: Self.definition.risk,
                summary: "Create reminder '\(input.title)' in \(destination)."
            )
        }

        public func call(
            _ input: Input,
            workspace _: WorkspaceContext?
        ) async throws -> Output {
            try await provider.createReminder(
                input
            )
        }

        public func classify(
            _ error: any Error,
            phase: ToolCall.Phase,
            input _: Input?
        ) -> Recovery.Incident? {
            guard
                phase == .call,
                let error = error
                    as? RemindersAuthorizationRequiredError
            else {
                return nil
            }

            return Recovery.Incident(
                kind: .authorization_required,
                stage: .execution,
                effectState: .not_applied,
                retrySafety: .safe,
                scope: .init(
                    kind: .tool,
                    identifier:
                        Self.definition.identifier.rawValue
                ),
                message: error.localizedDescription
            )
        }
    }

    @Tool("reminders")
    struct ReadReminders {
        @JSONSchema
        public struct Input:
            Codable,
            Sendable,
            Hashable
        {
            /// Maximum number of reminders to return. The provider clamps this to 1...200.
            public let limit: Int

            public init(
                limit: Int
            ) {
                self.limit = limit
            }
        }

        public typealias Output = [ReminderItem]

        public static let purpose =
            "Read reminders using the configured Apple Reminders provider."
        public static let risk: ActionRisk = .observe

        private let provider: any AppleRemindersProvider

        public init(
            provider: any AppleRemindersProvider
        ) {
            self.provider = provider
        }

        public func call(
            _ input: Input,
            workspace _: WorkspaceContext?
        ) async throws -> Output {
            try await provider.reminders(
                limit: input.limit
            )
        }
    }
}
