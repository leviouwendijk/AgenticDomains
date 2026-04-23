import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct RelayWebSearchProviderConfiguration: Sendable, Codable, Hashable {
    public let baseURL: URL
    public let apiKey: String?
    public let searchPath: String
    public let userAgent: String
    public let timeoutSeconds: TimeInterval

    public init(
        baseURL: URL,
        apiKey: String? = nil,
        searchPath: String = "search",
        userAgent: String = "AgenticWeb/1.0",
        timeoutSeconds: TimeInterval = 15
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.searchPath = searchPath
        self.userAgent = userAgent
        self.timeoutSeconds = timeoutSeconds
    }
}

public final class RelayWebSearchProvider: WebSearchProvider, @unchecked Sendable {
    public let configuration: RelayWebSearchProviderConfiguration
    public let policy: WebAccessPolicy
    public let extractor: HTMLTextExtractor
    public let downloader: IncrementalURLSessionDownloader

    public init(
        configuration: RelayWebSearchProviderConfiguration,
        policy: WebAccessPolicy = .default,
        extractor: HTMLTextExtractor = .init()
    ) {
        self.configuration = configuration
        self.policy = policy
        self.extractor = extractor
        self.downloader = .init(
            policy: policy,
            configuration: .init(
                userAgent: configuration.userAgent,
                timeoutSeconds: configuration.timeoutSeconds
            )
        )
    }

    public func search(
        _ request: WebSearchRequest
    ) async throws -> WebSearchResponse {
        let url = try searchURL(
            for: request
        )
        _ = try policy.validate(
            urlString: url.absoluteString
        )

        var urlRequest = URLRequest(
            url: url
        )
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        if let apiKey = configuration.apiKey,
           !apiKey.isEmpty {
            urlRequest.setValue(
                "Bearer \(apiKey)",
                forHTTPHeaderField: "Authorization"
            )
        }

        let download = try await downloader.download(
            urlRequest,
            maxBytes: policy.maxFetchedBytes,
            allowedContentTypes: ["application/json"]
        )

        guard (200..<300).contains(
            download.response.statusCode
        ) else {
            throw WebToolError.invalidStatusCode(
                download.response.statusCode
            )
        }

        let envelope: RelaySearchEnvelope
        do {
            envelope = try JSONDecoder().decode(
                RelaySearchEnvelope.self,
                from: download.body
            )
        } catch {
            throw WebToolError.invalidRelayResponse(
                "Expected provider/query/results JSON envelope."
            )
        }

        let filteredResults: [WebSearchResultSummary] = envelope.results.compactMap {
            (result: RelaySearchResult) -> WebSearchResultSummary? in
            guard policy.allows(
                urlString: result.url
            ) else {
                return nil
            }

            let host = URL(
                string: result.url
            )?.host?.lowercased()
                ?? result.displayHost
                ?? ""

            let stableID = result.id ?? Self.resultID(
                url: result.url,
                title: result.title
            )

            return WebSearchResultSummary(
                id: stableID,
                title: result.title,
                url: result.url,
                displayHost: host,
                snippet: result.snippet
            )
        }

        return .init(
            query: envelope.query ?? request.query,
            results: Array(
                filteredResults.prefix(
                    request.limit
                )
            ),
            provider: envelope.provider,
            fetchedAt: Date()
        )
    }

    public func fetch(
        _ request: WebFetchRequest
    ) async throws -> WebFetchResponse {
        let validatedURL = try policy.validate(
            urlString: request.url
        )

        var urlRequest = URLRequest(
            url: validatedURL
        )
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(
            "text/html, text/plain;q=0.9, application/json;q=0.5",
            forHTTPHeaderField: "Accept"
        )

        let download = try await downloader.download(
            urlRequest,
            maxBytes: request.maxBytes,
            allowedContentTypes: policy.allowedContentTypes
        )

        guard (200..<300).contains(
            download.response.statusCode
        ) else {
            throw WebToolError.invalidStatusCode(
                download.response.statusCode
            )
        }

        guard let finalURL = download.response.url else {
            throw WebToolError.invalidURL(
                request.url
            )
        }

        _ = try policy.validate(
            urlString: finalURL.absoluteString
        )

        let normalizedContentType = policy.normalizedContentType(
            download.response.value(
                forHTTPHeaderField: "Content-Type"
            )
        )

        let title: String?
        let text: String

        switch normalizedContentType {
        case "text/html":
            let document = try extractor.extract(
                from: download.body
            )
            title = document.title
            text = truncated(
                document.text,
                maxCharacters: request.maxCharacters
            )

        case "text/plain", "application/json":
            title = nil
            text = truncated(
                try decodedText(
                    from: download.body
                ),
                maxCharacters: request.maxCharacters
            )

        default:
            throw WebToolError.unsupportedContentType(
                normalizedContentType
            )
        }

        return .init(
            requestedURL: validatedURL.absoluteString,
            finalURL: finalURL.absoluteString,
            title: title,
            contentType: normalizedContentType,
            text: text,
            fetchedAt: Date()
        )
    }
}

private extension RelayWebSearchProvider {
    struct RelaySearchEnvelope: Decodable {
        let provider: String
        let query: String?
        let results: [RelaySearchResult]
    }

    struct RelaySearchResult: Decodable {
        let id: String?
        let title: String
        let url: String
        let displayHost: String?
        let snippet: String?
    }

    func searchURL(
        for request: WebSearchRequest
    ) throws -> URL {
        let baseURL = configuration.baseURL
            .appendingPathComponent(
                configuration.searchPath
            )

        guard var components = URLComponents(
            url: baseURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw WebToolError.invalidURL(
                baseURL.absoluteString
            )
        }

        var queryItems: [URLQueryItem] = [
            .init(
                name: "q",
                value: request.query
            ),
            .init(
                name: "limit",
                value: String(request.limit)
            ),
            .init(
                name: "safe_search",
                value: request.safeSearch ? "1" : "0"
            )
        ]

        if let freshnessDays = request.freshnessDays {
            queryItems.append(
                .init(
                    name: "freshness_days",
                    value: String(freshnessDays)
                )
            )
        }

        for site in request.siteRestrictions {
            let trimmed = site.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !trimmed.isEmpty else {
                continue
            }

            queryItems.append(
                .init(
                    name: "site",
                    value: trimmed
                )
            )
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw WebToolError.invalidURL(
                baseURL.absoluteString
            )
        }

        return url
    }

    func decodedText(
        from data: Data
    ) throws -> String {
        if let value = String(
            data: data,
            encoding: .utf8
        ) {
            return normalizePlainText(
                value
            )
        }

        if let value = String(
            data: data,
            encoding: .isoLatin1
        ) {
            return normalizePlainText(
                value
            )
        }

        if let value = String(
            data: data,
            encoding: .windowsCP1252
        ) {
            return normalizePlainText(
                value
            )
        }

        throw WebToolError.failedTextDecoding
    }

    func normalizePlainText(
        _ value: String
    ) -> String {
        value
            .replacingOccurrences(
                of: "\r\n",
                with: "\n"
            )
            .replacingOccurrences(
                of: "\r",
                with: "\n"
            )
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map { line in
                line.replacingOccurrences(
                    of: #"\s+"#,
                    with: " ",
                    options: .regularExpression
                ).trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }
            .joined(separator: "\n")
    }

    func truncated(
        _ value: String,
        maxCharacters: Int
    ) -> String {
        guard value.count > maxCharacters else {
            return value
        }

        let endIndex = value.index(
            value.startIndex,
            offsetBy: maxCharacters
        )

        return String(value[..<endIndex])
    }

    static func resultID(
        url: String,
        title: String
    ) -> String {
        let normalizedTitle = title
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
        let normalizedURL = url.lowercased()

        return "\(normalizedTitle)|\(normalizedURL)"
    }
}
