import Schema
import Version

@JSONSchema
struct AgenticSwiftEmptyToolInput: Codable {}

extension ObjectVersionLevel:
    @retroactive JSONSchemaProviding
{
    public static var jsonschema: JSONSchema {
        .string(
            cases: allCases.map(\.rawValue)
        )
    }
}
