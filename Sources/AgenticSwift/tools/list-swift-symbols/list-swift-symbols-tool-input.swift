import Agentic
import Primitives

public struct ListSwiftSymbolsToolInput: Sendable, Codable, Hashable {
    public let path: String
    public let includeKinds: [SwiftSymbolKind]
    public let maxSymbols: Int?

    public init(
        path: String,
        includeKinds: [SwiftSymbolKind] = [],
        maxSymbols: Int? = nil
    ) {
        self.path = path
        self.includeKinds = includeKinds
        self.maxSymbols = maxSymbols
    }

    private enum CodingKeys:
        String,
        CodingKey
    {
        case path
        case includeKinds
        case maxSymbols
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
            includeKinds: try container.decodeIfPresent(
                [SwiftSymbolKind].self,
                forKey: .includeKinds
            ) ?? [],
            maxSymbols: try container.decodeIfPresent(
                Int.self,
                forKey: .maxSymbols
            )
        )
    }
}

public extension ListSwiftSymbolsToolInput {
    static var schema: JSONValue {
        JSONSchema.object {
            JSONSchema.string(
                "path",
                required: true,
                description:
                    "Swift source file path relative to the current Agentic workspace."
            )

            JSONSchema.array(
                "includeKinds",
                description:
                    "Optional Swift symbol kinds to include. Omit or pass an empty array to include all kinds. Allowed values: \(SwiftSymbolKind.allCases.map(\.rawValue).joined(separator: ", ")).",
                items: JSONSchema.Value.string()
            )

            JSONSchema.integer(
                "maxSymbols",
                description:
                    "Optional maximum number of symbols to return. Defaults to 200 and is clamped to at least 1."
            )
        }
    }

    var clampedMaxSymbols: Int {
        guard let maxSymbols else {
            return 200
        }

        return max(1, maxSymbols)
    }

    var filtersByKind: Bool {
        !includeKinds.isEmpty
    }
}
