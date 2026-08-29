import Schema
import SchemaMacros

/// Search the public web through the configured bounded provider.
@JSONSchema
public struct SearchWebToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Search query text.
    public let query: String

    /// Optional result limit. The active WebAccessPolicy clamps the final value.
    public let limit: Int?

    /// Optional provider site restrictions. Defaults to an empty array.
    @Schema(required: false)
    public let siteRestrictions: [String]

    /// Optional freshness window in days.
    public let freshnessDays: Int?

    public init(
        query: String,
        limit: Int? = nil,
        siteRestrictions: [String] = [],
        freshnessDays: Int? = nil
    ) {
        self.query = query
        self.limit = limit
        self.siteRestrictions = siteRestrictions
        self.freshnessDays = freshnessDays
    }
}

private extension SearchWebToolInput {
    enum CodingKeys:
        String,
        CodingKey
    {
        case query
        case limit
        case siteRestrictions
        case freshnessDays
    }
}

public extension SearchWebToolInput {
    init(
        from decoder: any Decoder
    ) throws {
        let container =
            try decoder.container(
                keyedBy:
                    CodingKeys.self
            )

        self.init(
            query:
                try container.decode(
                    String.self,
                    forKey:
                        .query
                ),
            limit:
                try container.decodeIfPresent(
                    Int.self,
                    forKey:
                        .limit
                ),
            siteRestrictions:
                try container.decodeIfPresent(
                    [String].self,
                    forKey:
                        .siteRestrictions
                ) ?? [],
            freshnessDays:
                try container.decodeIfPresent(
                    Int.self,
                    forKey:
                        .freshnessDays
                )
        )
    }
}
