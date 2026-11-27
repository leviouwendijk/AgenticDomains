import Agentic
import Loa
import Primitives

public extension Loa.Catalog {
    /// The catalog a Loa program sees, from the same descriptors the model's tool
    /// definitions come from, so there is one source for both. `mail_tool_search` becomes
    /// `mail.search`; tools whose identifier is not `<domain>_tool_<name>` are left out.
    /// Results are `any` until tools declare an output schema.
    init(tools: [ToolDescriptor], domains: [DomainDefinition] = []) {
        var order: [String] = []
        var functions: [String: [Loa.Function]] = [:]
        for tool in tools {
            guard let identity = try? CapabilityIdentity(tool.identifier.rawValue), identity.kind == .tool else {
                continue
            }
            let domain = identity.domain.raw
            if functions[domain] == nil { order.append(domain) }
            functions[domain, default: []].append(
                .init(
                    identity.name.raw,
                    parameters: Self.parameters(tool.input),
                    result: .any,
                    effect: Self.effect(tool.risk),
                    summary: Self.summary(tool.description)
                )
            )
        }
        self.init(domains: order.map { name in
            let aliases = domains.first { $0.name?.raw == name }?.aliases.map(\.raw) ?? []
            return Loa.Domain(name, aliases: aliases, functions: functions[name] ?? [])
        })
    }

    /// How the dispatcher's risk reads as a Loa effect.
    static func effect(_ risk: ActionRisk) -> Loa.Effect {
        switch risk {
        case .observe: .read
        case .boundedmutate: .mutate
        case .privileged, .forbidden: .external
        }
    }

    /// The first sentence of a description, for the one-line reference.
    static func summary(_ description: String) -> String {
        let firstLine = description.split(separator: "\n").first.map(String.init) ?? ""
        if let end = firstLine.range(of: ". ") {
            return String(firstLine[..<end.lowerBound]) + "."
        }
        return firstLine
    }

    /// A tool's input schema as labeled parameters: required ones first, in their declared
    /// order, then the optional ones by name.
    static func parameters(_ schema: JSONValue?) -> [Loa.Parameter] {
        guard case .object(let object)? = schema, case .object(let properties)? = object["properties"] else {
            return []
        }
        var required: [String] = []
        if case .array(let names)? = object["required"] {
            required = names.compactMap { if case .string(let name) = $0 { name } else { nil } }
        }
        let optional = properties.keys.filter { !required.contains($0) }.sorted()
        return (required.filter { properties[$0] != nil } + optional).map { name in
            Loa.Parameter(name, valueType(properties[name] ?? .null), required: required.contains(name))
        }
    }

    /// A JSON schema as a Loa type; anything it cannot read is `any`, so checking stays gradual.
    static func valueType(_ schema: JSONValue) -> Loa.ValueType {
        guard case .object(let object) = schema else { return .any }
        for key in ["anyOf", "oneOf"] {
            if case .array(let options)? = object[key] {
                let types = options.filter { option in
                    if case .object(let fields) = option, fields["type"] == .string("null") { return false }
                    return true
                }
                if types.count == 1 {
                    let wrapped = valueType(types[0])
                    return types.count < options.count ? .optional(wrapped) : wrapped
                }
                return .any
            }
        }
        if case .array(let names)? = object["enum"] {
            let cases = names.compactMap { if case .string(let name) = $0 { name } else { nil } }
            if cases.count == names.count, cases.allSatisfy(isName) {
                return .cases(.init(nil, cases))
            }
        }
        switch object["type"] {
        case .array(let types)?:
            let present = types.filter { $0 != .string("null") }
            guard present.count == 1 else { return .any }
            var single = object
            single["type"] = present[0]
            let wrapped = valueType(.object(single))
            return present.count < types.count ? .optional(wrapped) : wrapped
        case .string("string")?:
            return .string
        case .string("integer")?:
            return .int
        case .string("number")?:
            return .double
        case .string("boolean")?:
            return .bool
        case .string("null")?:
            return .null
        case .string("array")?:
            return .array(object["items"].map(valueType) ?? .any)
        case .string("object")?:
            if case .object(let properties)? = object["properties"] {
                var required: [String] = []
                if case .array(let names)? = object["required"] {
                    required = names.compactMap { if case .string(let name) = $0 { name } else { nil } }
                }
                return .record(.init(nil, properties.keys.sorted().map { name in
                    let type = valueType(properties[name] ?? .null)
                    return Loa.Field(name, required.contains(name) ? type : .optional(type))
                }))
            }
            if let values = object["additionalProperties"], case .object = values {
                return .dictionary(.string, valueType(values))
            }
            return .any
        default:
            return .any
        }
    }

    /// Whether an enum value can be written as a Loa case (`.read`).
    static func isName(_ text: String) -> Bool {
        guard let first = text.unicodeScalars.first, first == "_" || first.properties.isAlphabetic else { return false }
        return text.unicodeScalars.allSatisfy { $0 == "_" || $0.properties.isAlphabetic || ("0"..."9").contains($0) }
    }
}
