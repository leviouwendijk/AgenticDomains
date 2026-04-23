import Agentic

public struct AgenticSwiftSkillProvider: AgentSkillProvider {
    public init() {}

    public func registerSkills(
        into registry: inout SkillRegistry
    ) throws {
        try registry.register(
            [
                Self.swiftStructuralReading,
                Self.swiftTargetedEditing
            ]
        )
    }
}

public extension AgenticSwiftSkillProvider {
    static let swiftStructuralReading = AgentSkill(
        identifier: "swift-structural-reading",
        name: "Swift structural reading",
        summary: "Use Swift structural and symbol tools before broad file reads.",
        body: """
        Prefer Swift structural tools when inspecting Swift source.

        Workflow:
        1. Use `\(ListSwiftSymbolsTool.identifier.rawValue)` to map symbols in a file before reading large source ranges.
        2. Use `\(ReadSwiftSymbolTool.identifier.rawValue)` when an exact type, function, initializer, property, enum case, or extension is needed.
        3. Use `\(ReadSwiftStructureTool.identifier.rawValue)` for enclosing scopes, imports, declarations, members, and type-level selections.
        4. Fall back to `\(ReadFileTool.identifier.rawValue)` only when the structural tools cannot answer the question.
        5. Preserve source line ranges in your explanation when they matter for review or patching.
        """,
        metadata: .init(
            domains: [.swift],
            tools: .init(
                required: [
                    .tool(ListSwiftSymbolsTool.self),
                    .tool(ReadSwiftSymbolTool.self),
                    .tool(ReadSwiftStructureTool.self)
                ],
                optional: [
                    .tool(ReadFileTool.self, owner: "Agentic")
                ]
            ),
            tags: [
                "swift",
                "symbols",
                "context"
            ]
        )
    )

    static let swiftTargetedEditing = AgentSkill(
        identifier: "swift-targeted-editing",
        name: "Swift targeted editing",
        summary: "Plan Swift edits around symbols, contiguous ranges, and compileable changes.",
        body: """
        Use symbol-level inspection before editing Swift files.

        Editing workflow:
        1. Identify the smallest relevant symbol or enclosing scope.
        2. Read only the relevant symbol/body/range unless broader context is needed.
        3. Prefer contiguous edits with clear replacement boundaries.
        4. Preserve access control, Sendable/Codable/Hashable conformances, naming style, and existing file organization.
        5. After editing, inspect the changed symbol or surrounding scope again if available.
        6. When a build or test tool exists, use it after non-trivial Swift edits.
        """,
        metadata: .init(
            domains: [.swift],
            tools: .init(
                required: [
                    .tool(ReadSwiftSymbolTool.self),
                    .tool(ReadSwiftStructureTool.self)
                ],
                optional: [
                    .tool(EditFileTool.self, owner: "Agentic")
                ]
            ),
            tags: [
                "swift",
                "editing",
                "refactoring"
            ]
        )
    )
}
