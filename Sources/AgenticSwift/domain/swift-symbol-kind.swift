public enum SwiftSymbolKind: String, Sendable, Codable, Hashable, CaseIterable {
    case `import`
    case `struct`
    case `class`
    case actor
    case `enum`
    case `protocol`
    case `extension`
    case typealias_decl
    case function
    case initializer
    case subscript_decl
    case variable
    case enum_case
}
