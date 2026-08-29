import Agentic
import Foundation
import Primitives
import Schema
import SchemaMacros

/// Read one exact Swift symbol.
/// Supply either id or displayName.
/// When using displayName, parentType and kind may further disambiguate the symbol.
@JSONSchema
public struct ReadSwiftSymbolToolInput: Sendable, Codable, Hashable {
    /// Swift source file path relative to the current Agentic workspace.
    public let path: String

    /// Exact symbol identifier returned by list_swift_symbols. Supply id or displayName.
    public let id: String?

    /// Exact symbol display name returned by list_swift_symbols. Supply displayName or id.
    public let displayName: String?

    /// Optional parent type used when disambiguating displayName.
    public let parentType: String?

    /// Optional symbol kind used when disambiguating displayName.
    public let kind: SwiftSymbolKind?

    /// Whether returned source content includes line-number prefixes. Defaults to true.
    @Schema(required: false)
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

private extension ReadSwiftSymbolToolInput {
    enum CodingKeys:
        String,
        CodingKey
    {
        case path
        case id
        case displayName
        case parentType
        case kind
        case includeLineNumbers
    }
}

public extension ReadSwiftSymbolToolInput {
    init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        self.init(
            path: try container.decode(
                String.self,
                forKey: .path
            ),
            id: try container.decodeIfPresent(
                String.self,
                forKey: .id
            ),
            displayName: try container.decodeIfPresent(
                String.self,
                forKey: .displayName
            ),
            parentType: try container.decodeIfPresent(
                String.self,
                forKey: .parentType
            ),
            kind: try container.decodeIfPresent(
                SwiftSymbolKind.self,
                forKey: .kind
            ),
            includeLineNumbers: try container.decodeIfPresent(
                Bool.self,
                forKey: .includeLineNumbers
            ) ?? true
        )
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
