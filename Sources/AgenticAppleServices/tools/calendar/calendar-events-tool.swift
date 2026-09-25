import Agentic
import Macros
import Schema
import Workspace

public extension AppleServices.Tools {
    @Tool("calendar_events")
    struct ReadCalendarEvents {
        @JSONSchema
        public struct Input:
            Codable,
            Sendable,
            Hashable
        {
            /// Inclusive query start as an ISO 8601 timestamp.
            public let startDate: String

            /// Exclusive query end as an ISO 8601 timestamp.
            public let endDate: String

            /// Maximum number of events to return. The provider clamps this to 1...200.
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

        public typealias Output = [CalendarEvent]

        public static let purpose =
            "Read calendar events in an explicit ISO 8601 time range using the configured Apple Calendar provider."
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
            try await provider.events(
                .init(
                    startDate: input.startDate,
                    endDate: input.endDate,
                    limit: input.limit
                )
            )
        }
    }
}
