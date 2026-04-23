public protocol WebSearchProvider: Sendable {
    func search(
        _ request: WebSearchRequest
    ) async throws -> WebSearchResponse

    func fetch(
        _ request: WebFetchRequest
    ) async throws -> WebFetchResponse
}
