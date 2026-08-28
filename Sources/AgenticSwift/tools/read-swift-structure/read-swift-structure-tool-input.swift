import Agentic
import AgenticWorkspace
import Primitives

public struct ReadSwiftStructureToolInput: Sendable, Codable, Hashable {
    public enum QueryKind: String, Sendable, Codable, Hashable, CaseIterable {
        case declaration
        case type
        case member
        case imports
        case enclosing_scope
    }

    public let path: String
    public let queryKind: QueryKind
    public let name: String?
    public let parentType: String?
    public let line: Int?
    public let column: Int?
    public let maxMatches: Int?
    public let includeLineNumbers: Bool

    public init(
        path: String,
        queryKind: QueryKind,
        name: String? = nil,
        parentType: String? = nil,
        line: Int? = nil,
        column: Int? = nil,
        maxMatches: Int? = nil,
        includeLineNumbers: Bool = true
    ) {
        self.path = path
        self.queryKind = queryKind
        self.name = name
        self.parentType = parentType
        self.line = line
        self.column = column
        self.maxMatches = maxMatches
        self.includeLineNumbers = includeLineNumbers
    }

    private enum CodingKeys:
        String,
        CodingKey
    {
        case path
        case queryKind
        case name
        case parentType
        case line
        case column
        case maxMatches
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
            queryKind: try container.decode(
                QueryKind.self,
                forKey: .queryKind
            ),
            name: try container.decodeIfPresent(
                String.self,
                forKey: .name
            ),
            parentType: try container.decodeIfPresent(
                String.self,
                forKey: .parentType
            ),
            line: try container.decodeIfPresent(
                Int.self,
                forKey: .line
            ),
            column: try container.decodeIfPresent(
                Int.self,
                forKey: .column
            ),
            maxMatches: try container.decodeIfPresent(
                Int.self,
                forKey: .maxMatches
            ),
            includeLineNumbers: try container.decodeIfPresent(
                Bool.self,
                forKey: .includeLineNumbers
            ) ?? true
        )
    }
}

public extension ReadSwiftStructureToolInput {
    static var schema: JSONValue {
        JSONSchema.object(
            description:
                """
                Read a semantic Swift structure from one source file.
                declaration/type/member require name.
                member optionally accepts parentType.
                enclosing_scope requires a positive 1-based line and optionally a positive 1-based column.
                imports needs no additional query fields.
                """
        ) {
            JSONSchema.string(
                "path",
                required: true,
                description:
                    "Swift source file path relative to the current Agentic workspace."
            )

            JSONSchema.string(
                "queryKind",
                required: true,
                description:
                    "Semantic structure query kind.",
                cases:
                    QueryKind.allCases.map(\.rawValue)
            )

            JSONSchema.string(
                "name",
                description:
                    "Required for declaration, type, and member queries."
            )

            JSONSchema.string(
                "parentType",
                description:
                    "Optional parent type used to disambiguate a member query."
            )

            JSONSchema.integer(
                "line",
                description:
                    "Required positive 1-based line for enclosing_scope."
            )

            JSONSchema.integer(
                "column",
                description:
                    "Optional positive 1-based column for enclosing_scope."
            )

            JSONSchema.integer(
                "maxMatches",
                description:
                    "Optional maximum number of matches. Defaults to 8 and is clamped to at least 1."
            )

            JSONSchema.boolean(
                "includeLineNumbers",
                description:
                    "Whether returned source content includes line-number prefixes. Defaults to true."
            )
        }
    }

    func structuralQuery() throws -> StructuralQuery {
        switch queryKind {
        case .declaration:
            guard let name,
                  !name.isEmpty else {
                throw SwiftStructuralSelectorError.missingNamedQueryValue(
                    "name"
                )
            }

            return .declaration(
                named: name
            )

        case .type:
            guard let name,
                  !name.isEmpty else {
                throw SwiftStructuralSelectorError.missingNamedQueryValue(
                    "name"
                )
            }

            return .type(
                named: name
            )

        case .member:
            guard let name,
                  !name.isEmpty else {
                throw SwiftStructuralSelectorError.missingNamedQueryValue(
                    "name"
                )
            }

            return .member(
                named: name,
                parentType: parentType
            )

        case .imports:
            return .imports

        case .enclosing_scope:
            guard let line,
                  line > 0 else {
                throw SwiftStructuralSelectorError.invalidLocation(
                    line: line ?? 0,
                    column: column
                )
            }

            if let column,
               column <= 0 {
                throw SwiftStructuralSelectorError.invalidLocation(
                    line: line,
                    column: column
                )
            }

            return .enclosingScope(
                .init(
                    line: line,
                    column: column
                )
            )
        }
    }

    var clampedMaxMatches: Int {
        guard let maxMatches else {
            return 8
        }

        return max(1, maxMatches)
    }
}
