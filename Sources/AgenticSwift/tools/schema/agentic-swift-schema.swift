import Schema
import Macros
import Position
import Version


extension ObjectVersionLevel:
    @retroactive JSONSchemaProviding
{
    public static var jsonschema: JSONSchema {
        .string(
            cases: allCases.map(\.rawValue)
        )
    }
}

extension LineRange:
    @retroactive JSONSchemaProviding
{
    public static var jsonschema: JSONSchema {
        JSONSchema.object(
            additionalProperties: .disallowed
        ) {
            JSONSchema.property(
                "start",
                schema: Int.jsonschema,
                required: true
            )

            JSONSchema.property(
                "end",
                schema: Int.jsonschema,
                required: true
            )
        }
    }
}
