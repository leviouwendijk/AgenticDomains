import Agentic
import Foundation
import Primitives

public struct OpenWebResultTool: AgentTool {
    public static let identifier: AgentToolIdentifier = "open_web_result"
    public static let description = "Open one previously returned search result by searchID and resultID and return sandboxed extracted text."
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
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        _ = workspace

        let decoded = try JSONToolBridge.decode(
            OpenWebResultToolInput.self,
            from: input
        )
        let record = try await requiredRecord(
            searchID: decoded.searchID
        )
        let result = try requiredResult(
            in: record,
            resultID: decoded.resultID
        )
        let url = try policy.validate(
            urlString: result.url
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: nil,
            summary: """
            Open previously returned web result "\(result.title)" from search "\(record.query)".
            """,
            commandPreview: "GET \(url.absoluteString)",
            estimatedByteCount: policy.maxFetchedBytes,
            estimatedRuntimeSeconds: 8,
            sideEffects: [
                "external network read"
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        _ = workspace

        let decoded = try JSONToolBridge.decode(
            OpenWebResultToolInput.self,
            from: input
        )
        let record = try await requiredRecord(
            searchID: decoded.searchID
        )
        let result = try requiredResult(
            in: record,
            resultID: decoded.resultID
        )
        let validatedURL = try policy.validate(
            urlString: result.url
        )
        let characterLimit = policy.normalizedCharacterLimit(
            decoded.maxCharacters
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

        return try JSONToolBridge.encode(
            OpenWebResultToolOutput(
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
        )
    }
}

private extension OpenWebResultTool {
    func requiredRecord(
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

    func requiredResult(
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

    func truncate(
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
