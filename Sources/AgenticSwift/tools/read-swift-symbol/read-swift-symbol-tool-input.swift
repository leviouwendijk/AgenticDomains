import Agentic
import Foundation
import Primitives

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

    private enum CodingKeys:
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

    public init(
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
    static var schema: JSONValue {
        JSONSchema.object(
            description:
                """
                Read one exact Swift symbol.
                Supply either id or displayName.
                When using displayName, parentType and kind may further disambiguate the symbol.
                """
        ) {
            JSONSchema.string(
                "path",
                required: true,
                description:
                    "Swift source file path relative to the current Agentic workspace."
            )

            JSONSchema.string(
                "id",
                description:
                    "Exact symbol identifier returned by list_swift_symbols. Supply id or displayName."
            )

            JSONSchema.string(
                "displayName",
                description:
                    "Exact symbol display name returned by list_swift_symbols. Supply displayName or id."
            )

            JSONSchema.string(
                "parentType",
                description:
                    "Optional parent type used when disambiguating displayName."
            )

            JSONSchema.string(
                "kind",
                description:
                    "Optional symbol kind used when disambiguating displayName.",
                cases:
                    SwiftSymbolKind.allCases.map(\.rawValue)
            )

            JSONSchema.boolean(
                "includeLineNumbers",
                description:
                    "Whether returned source content includes line-number prefixes. Defaults to true."
            )
        }
    }

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
