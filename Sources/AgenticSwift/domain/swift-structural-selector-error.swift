import Foundation

public enum SwiftStructuralSelectorError: Error, Sendable, LocalizedError {
    case unsupportedFile(String)
    case invalidLocation(line: Int, column: Int?)
    case missingNamedQueryValue(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFile(let path):
            return "SwiftStructuralSelector only supports Swift source files. Received: \(path)"
        case .invalidLocation(let line, let column):
            if let column {
                return "Invalid structural location line=\(line), column=\(column)."
            }

            return "Invalid structural location line=\(line)."
        case .missingNamedQueryValue(let field):
            return "Missing required value for query field '\(field)'."
        }
    }
}
