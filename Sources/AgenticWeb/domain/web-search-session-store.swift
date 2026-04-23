import Foundation

public actor WebSearchSessionStore {
    public struct Record: Sendable, Codable, Hashable, Identifiable {
        public let id: String
        public let query: String
        public let results: [WebSearchResultSummary]
        public let createdAt: Date

        public init(
            id: String,
            query: String,
            results: [WebSearchResultSummary],
            createdAt: Date
        ) {
            self.id = id
            self.query = query
            self.results = results
            self.createdAt = createdAt
        }
    }

    private var records: [String: Record]

    public init() {
        self.records = [:]
    }

    @discardableResult
    public func store(
        query: String,
        results: [WebSearchResultSummary]
    ) -> Record {
        let record = Record(
            id: UUID().uuidString,
            query: query,
            results: results,
            createdAt: Date()
        )

        records[record.id] = record
        return record
    }

    public func record(
        id: String
    ) -> Record? {
        records[id]
    }
}
