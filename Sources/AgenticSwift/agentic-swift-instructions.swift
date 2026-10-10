import Agentic
import AgenticIO

/// Reusable guidance. Instructions neither install nor expose Tools.
public extension SwiftLang.Instructions {
    @Instruction
    enum StructuralReading {
        public static let content = """
        Prefer Swift structural tools when inspecting Swift source.

        Workflow:
        1. Use `\(ListSwiftSymbolsTool.identifier.rawValue)` to map symbols in a file before reading large source ranges.
        2. Use `\(ReadSwiftSymbolTool.identifier.rawValue)` when an exact type, function, initializer, property, enum case, or extension is needed.
        3. Use `\(ReadSwiftStructureTool.identifier.rawValue)` for enclosing scopes, imports, declarations, members, and type-level selections.
        4. Fall back to `read_file` only when the structural tools cannot answer the question.
        5. Preserve source line ranges in your explanation when they matter for review or patching.
        """
    }

    @Instruction
    enum TargetedEditing {
        public static let content = """
        Use symbol-level inspection before editing Swift files.

        Editing workflow:
        1. Identify the smallest relevant symbol or enclosing scope.
        2. Read only the relevant symbol/body/range unless broader context is needed.
        3. Prefer one coherent `mutate_files` pass for related file changes.
        4. Use `create_text`, `replace_text`, `edit_text`, or `delete` entries rather than separate write/edit tools.
        5. For `edit_text`, use contiguous operations with clear replacement boundaries.
        6. Preserve access control, Sendable/Codable/Hashable conformances, naming style, and existing file organization.
        7. After editing, inspect the changed symbol or surrounding scope again if available.
        8. When a build or test tool exists, use it after non-trivial Swift edits.
        """
    }
}
