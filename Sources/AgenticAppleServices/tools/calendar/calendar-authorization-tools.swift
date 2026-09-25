import Agentic
import Macros
import Schema
import Workspace

public extension AppleServices.Tools {
    @Tool("calendar_authorization_status")
    struct ReadCalendarAuthorizationStatus {
        @JSONSchema
        public struct Input:
            Codable,
            Sendable,
            Hashable
        {
            public init() {}
        }

        public typealias Output = CalendarAuthorizationStatus

        public static let purpose =
            "Observe the current macOS Calendar authorization status without requesting permission."
        public static let risk: ActionRisk = .observe

        private let provider: any AppleCalendarProvider

        public init(
            provider: any AppleCalendarProvider
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

    @Tool("calendar_request_full_access")
    struct RequestCalendarFullAccess {
        @JSONSchema
        public struct Input:
            Codable,
            Sendable,
            Hashable
        {
            public init() {}
        }

        public typealias Output = CalendarAuthorizationRequestResult

        public static let purpose =
            "Request full access to the user's calendars through the macOS EventKit privacy permission flow."
        public static let risk: ActionRisk = .boundedmutate

        private let provider: any AppleCalendarProvider

        public init(
            provider: any AppleCalendarProvider
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
}
