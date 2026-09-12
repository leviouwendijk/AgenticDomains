import Interfaces
import Schema
import Macros

@JSONSchema
public struct AgenticGitEmptyToolInput:
    Codable,
    Sendable
{
    public init() {}
}

extension GitManagerDiffScope:
    @retroactive JSONSchemaProviding
{
    public static var jsonschema: JSONSchema {
        .string(
            cases: allCases.map(\.rawValue)
        )
    }
}
