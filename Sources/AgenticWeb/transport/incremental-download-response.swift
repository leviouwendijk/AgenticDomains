import Foundation

public struct IncrementalDownloadResponse: Sendable {
    public let response: HTTPURLResponse
    public let body: Data

    public init(
        response: HTTPURLResponse,
        body: Data
    ) {
        self.response = response
        self.body = body
    }
}
