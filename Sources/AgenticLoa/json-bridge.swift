import Loa
import Primitives

public extension Loa.Value {
    /// A tool's JSON as a Loa value. Object keys are sorted: JSON objects have no order,
    /// and a stable order keeps ledger hashes stable.
    init(json: JSONValue) {
        switch json {
        case .string(let text):
            self = .string(text)
        case .int(let number):
            self = .int(number)
        case .double(let number):
            self = .double(number)
        case .bool(let flag):
            self = .bool(flag)
        case .null:
            self = .null
        case .array(let elements):
            self = .array(elements.map(Loa.Value.init(json:)))
        case .object(let fields):
            self = .record(.init(nil, fields.keys.sorted().map { key in
                .init(key, Loa.Value(json: fields[key] ?? .null))
            }))
        }
    }
}

public extension JSONValue {
    /// A Loa value as tool input. A case without values is its name (`.read` → `"read"`),
    /// as JSON schemas write enums; a case with values is `{ name: values }`.
    init(loa value: Loa.Value) {
        switch value {
        case .null:
            self = .null
        case .bool(let flag):
            self = .bool(flag)
        case .int(let number):
            self = .int(number)
        case .double(let number):
            self = .double(number)
        case .string(let text):
            self = .string(text)
        case .array(let elements):
            self = .array(elements.map(JSONValue.init(loa:)))
        case .record(let record):
            self = .object(Dictionary(record.fields.map { ($0.name, JSONValue(loa: $0.value)) }, uniquingKeysWith: { _, last in last }))
        case .dictionary(let entries):
            if entries.allSatisfy({ if case .string = $0.key { true } else { false } }) {
                self = .object(Dictionary(entries.map { ($0.key.text, JSONValue(loa: $0.value)) }, uniquingKeysWith: { _, last in last }))
            } else {
                self = .array(entries.map { .object(["key": JSONValue(loa: $0.key), "value": JSONValue(loa: $0.value)]) })
            }
        case .case(let value):
            if value.arguments.isEmpty {
                self = .string(value.name)
            } else if value.arguments.allSatisfy({ $0.label != nil }) {
                let fields = Dictionary(value.arguments.map { ($0.label ?? "", JSONValue(loa: $0.value)) }, uniquingKeysWith: { _, last in last })
                self = .object([value.name: .object(fields)])
            } else {
                self = .object([value.name: .array(value.arguments.map { JSONValue(loa: $0.value) })])
            }
        case .failure(let failure):
            self = .object(["error": .string(failure.description)])
        }
    }
}
