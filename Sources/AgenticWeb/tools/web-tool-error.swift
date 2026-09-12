import Foundation

public enum WebToolError: Error, Sendable, LocalizedError {
    case providerUnavailable
    case emptyQuery
    case invalidURL(String)
    case invalidConfiguredHostRule(String)
    case unsupportedScheme(String)
    case disallowedHost(String)
    case disallowedPort(Int)
    case privateNetworkHost(String)
    case missingSearchRecord(String)
    case missingSearchResult(searchID: String, resultID: String)
    case nonHTTPResponse
    case invalidStatusCode(Int)
    case unsupportedContentType(String?)
    case responseTooLarge(limit: Int, actual: Int)
    case tooManyRedirects(limit: Int)
    case invalidRelayResponse(String)
    case failedTextDecoding
    case transportFailure(String)

    public var errorDescription: String? {
        switch self {
        case .providerUnavailable:
            return "No web search provider is configured."

        case .emptyQuery:
            return "Web search query must not be empty."

        case .invalidURL(let value):
            return "Invalid URL: \(value)"

        case .invalidConfiguredHostRule(let value):
            return "Invalid configured host rule: \(value)"

        case .unsupportedScheme(let scheme):
            return "Unsupported URL scheme: \(scheme)"

        case .disallowedHost(let host):
            return "Disallowed host: \(host)"

        case .disallowedPort(let port):
            return "Disallowed port: \(port)"

        case .privateNetworkHost(let host):
            return "Private or local network host is not allowed: \(host)"

        case .missingSearchRecord(let searchID):
            return "Search record not found: \(searchID)"

        case .missingSearchResult(let searchID, let resultID):
            return "Search result not found: searchID=\(searchID), resultID=\(resultID)"

        case .nonHTTPResponse:
            return "Expected an HTTP response."

        case .invalidStatusCode(let statusCode):
            return "Unexpected HTTP status code: \(statusCode)"

        case .unsupportedContentType(let contentType):
            return "Unsupported content type: \(contentType ?? "<missing>")"

        case .responseTooLarge(let limit, let actual):
            return "Response exceeded byte limit \(limit). Actual bytes: \(actual)"

        case .tooManyRedirects(let limit):
            return "Too many redirects. Limit: \(limit)"

        case .invalidRelayResponse(let details):
            return "Invalid relay response: \(details)"

        case .failedTextDecoding:
            return "Failed to decode response body as text."

        case .transportFailure(let details):
            return "Transport failed: \(details)"
        }
    }
}
