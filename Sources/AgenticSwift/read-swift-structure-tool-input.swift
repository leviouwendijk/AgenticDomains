import Agentic

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
}

public extension ReadSwiftStructureToolInput {
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
