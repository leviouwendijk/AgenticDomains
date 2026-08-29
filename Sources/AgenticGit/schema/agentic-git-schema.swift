import Interfaces
import Schema

@JSONSchema
struct AgenticGitEmptyToolInput: Codable {}

extension GitManagerDiffScope:
    @retroactive JSONSchemaProviding
{
    public static var jsonschema: JSONSchema {
        .string(
            cases: allCases.map(\.rawValue)
        )
    }
}
