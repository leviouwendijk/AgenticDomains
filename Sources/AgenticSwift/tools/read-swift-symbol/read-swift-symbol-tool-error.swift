import Foundation

public enum ReadSwiftSymbolToolError: Error, Sendable, LocalizedError {
    case missingLookup
    case symbolNotFound(path: String, lookup: String)
    case ambiguousSymbol(path: String, lookup: String, candidates: [String])

    public var errorDescription: String? {
        switch self {
        case .missingLookup:
            return "read_swift_symbol requires either 'id' or 'displayName'."

        case .symbolNotFound(let path, let lookup):
            return "No Swift symbol matched \(lookup) in \(path)."

        case .ambiguousSymbol(let path, let lookup, let candidates):
            let rendered = candidates.joined(separator: "; ")
            return "Multiple Swift symbols matched \(lookup) in \(path): \(rendered)"
        }
    }
}
