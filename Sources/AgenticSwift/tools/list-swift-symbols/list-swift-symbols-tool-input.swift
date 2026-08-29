import Agentic
import Primitives
import Schema

@JSONSchema
public struct ListSwiftSymbolsToolInput: Sendable, Codable, Hashable {
    /// Swift source file path relative to the current Agentic workspace.
    public let path: String

    /// Optional Swift symbol kinds to include. Omit or pass an empty array to include all kinds.
    @Schema(required: false)
    public let includeKinds: [SwiftSymbolKind]

    /// Optional maximum number of symbols to return. Defaults to 200 and is clamped to at least 1.
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
}

private extension ListSwiftSymbolsToolInput {
    enum CodingKeys:
        String,
        CodingKey
    {
        case path
        case includeKinds
        case maxSymbols
    }
}

public extension ListSwiftSymbolsToolInput {
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
