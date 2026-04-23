import Foundation

public struct ReadSwiftSymbolToolInput: Sendable, Codable, Hashable {
    public let path: String
    public let id: String?
    public let displayName: String?
    public let parentType: String?
    public let kind: SwiftSymbolKind?
    public let includeLineNumbers: Bool

    public init(
        path: String,
        id: String? = nil,
        displayName: String? = nil,
        parentType: String? = nil,
        kind: SwiftSymbolKind? = nil,
        includeLineNumbers: Bool = true
    ) {
        self.path = path
        self.id = id
        self.displayName = displayName
        self.parentType = parentType
        self.kind = kind
        self.includeLineNumbers = includeLineNumbers
    }
}

public extension ReadSwiftSymbolToolInput {
    var normalizedID: String? {
        normalized(id)
    }

    var normalizedDisplayName: String? {
        normalized(displayName)
    }

    var hasLookup: Bool {
        normalizedID != nil || normalizedDisplayName != nil
    }

    private func normalized(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty ? nil : trimmed
    }
}
