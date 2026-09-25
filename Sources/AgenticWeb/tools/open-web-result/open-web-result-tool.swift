import Agentic
import Foundation
import Macros
import Schema
import Workspace

public extension Web.Tools {
    @Tool("open_web_result")
    struct OpenResult {
        @JSONSchema
        public struct Input:
            Sendable,
            Codable,
            Hashable
        {
            /// Search record identifier returned by search_web.
            public let searchID: String

            /// Result identifier returned by search_web.
            public let resultID: String

            /// Optional maximum number of returned text characters.
            public let maxCharacters: Int?

            public init(
                searchID: String,
                resultID: String,
                maxCharacters: Int? = nil
            ) {
                self.searchID = searchID
                self.resultID = resultID
                self.maxCharacters = maxCharacters
            }
        }

        @JSONSchema
        public struct Output:
            Sendable,
            Codable,
            Hashable
        {
            public let searchID: String
            public let resultID: String
            public let title: String?
            public let url: String
            public let host: String
            public let contentType: String?
            public let fetchedAt: Date
            public let truncated: Bool
            public let text: String

            public init(
                searchID: String,
                resultID: String,
                title: String?,
                url: String,
                host: String,
                contentType: String?,
                fetchedAt: Date,
                truncated: Bool,
                text: String
            ) {
                self.searchID = searchID
                self.resultID = resultID
                self.title = title
                self.url = url
                self.host = host
                self.contentType = contentType
                self.fetchedAt = fetchedAt
                self.truncated = truncated
                self.text = text
            }
        }

        public static let purpose =
            "Open one previously returned search result by searchID and resultID and return sandboxed extracted text."
        public static let risk: ActionRisk = .observe

        public let provider: any WebSearchProvider
        public let policy: WebAccessPolicy
        public let sessionStore: WebSearchSessionStore

        public init(
            provider: any WebSearchProvider = UnavailableWebSearchProvider(),
            policy: WebAccessPolicy = .default,
            sessionStore: WebSearchSessionStore = .init()
        ) {
            self.provider = provider
            self.policy = policy
            self.sessionStore = sessionStore
        }

        public func preflight(
            _ input: Input,
            workspace _: WorkspaceContext?
        ) async throws -> ToolPreflight {
            let record = try await requiredRecord(
                searchID: input.searchID
            )
            let result = try requiredResult(
                in: record,
                resultID: input.resultID
            )
            let url = try policy.validate(
                urlString: result.url
            )

            return .init(
                tool: Self.definition.identifier,
                risk: Self.risk,
                summary: "Open previously returned web result \"\(result.title)\" from search \"\(record.query)\".",
                estimates: .init(
                    runtime: 8,
                    bytes: policy.maxFetchedBytes
                ),
                preview: .init(
                    command: "GET \(url.absoluteString)"
                ),
                sideEffects: [
                    "external network read",
                ]
            )
        }

        public func call(
            _ input: Input,
            workspace _: WorkspaceContext?
        ) async throws -> Output {
            let record = try await requiredRecord(
                searchID: input.searchID
            )
            let result = try requiredResult(
                in: record,
                resultID: input.resultID
            )
            let validatedURL = try policy.validate(
                urlString: result.url
            )
            let characterLimit = policy.normalizedCharacterLimit(
                input.maxCharacters
            )

            let response = try await provider.fetch(
                .init(
                    url: validatedURL.absoluteString,
                    maxBytes: policy.maxFetchedBytes,
                    maxCharacters: characterLimit
                )
            )

            let truncatedText = truncate(
                response.text,
                maxCharacters: characterLimit
            )
            let host = URL(
                string: response.finalURL
            )?.host ?? validatedURL.host ?? result.displayHost

            return Output(
                searchID: record.id,
                resultID: result.id,
                title: response.title ?? result.title,
                url: response.finalURL,
                host: host,
                contentType: response.contentType,
                fetchedAt: response.fetchedAt,
                truncated: truncatedText.truncated,
                text: truncatedText.text
            )
        }

        private func requiredRecord(
            searchID: String
        ) async throws -> WebSearchSessionStore.Record {
            guard let record = await sessionStore.record(
                id: searchID
            ) else {
                throw WebToolError.missingSearchRecord(
                    searchID
                )
            }

            return record
        }

        private func requiredResult(
            in record: WebSearchSessionStore.Record,
            resultID: String
        ) throws -> WebSearchResultSummary {
            guard let result = record.results.first(
                where: { $0.id == resultID }
            ) else {
                throw WebToolError.missingSearchResult(
                    searchID: record.id,
                    resultID: resultID
                )
            }

            return result
        }

        private func truncate(
            _ value: String,
            maxCharacters: Int
        ) -> (text: String, truncated: Bool) {
            guard value.count > maxCharacters else {
                return (value, false)
            }

            let endIndex = value.index(
                value.startIndex,
                offsetBy: maxCharacters
            )

            return (
                String(value[..<endIndex]),
                true
            )
        }
    }
}
