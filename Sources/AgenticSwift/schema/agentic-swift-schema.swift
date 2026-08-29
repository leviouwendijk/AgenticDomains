import Schema
import Version

@JSONSchema
public struct AgenticSwiftEmptyToolInput:
    Codable,
    Sendable
{
    public init() {}
}

extension ObjectVersionLevel:
    @retroactive JSONSchemaProviding
{
    public static var jsonschema: JSONSchema {
        .string(
            cases: allCases.map(\.rawValue)
        )
    }
}
