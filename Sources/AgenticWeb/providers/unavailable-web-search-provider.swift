public struct UnavailableWebSearchProvider: WebSearchProvider {
    public init() {}

    public func search(
        _ request: WebSearchRequest
    ) async throws -> WebSearchResponse {
        _ = request
        throw WebToolError.providerUnavailable
    }

    public func fetch(
        _ request: WebFetchRequest
    ) async throws -> WebFetchResponse {
        _ = request
        throw WebToolError.providerUnavailable
    }
}
