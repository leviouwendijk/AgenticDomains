import Agentic
import AgenticExecution
import SwiftSemantics

public struct InspectPackageGraphTool:
    AgentTool
{
    public typealias Input = AgenticSwiftEmptyToolInput
    public typealias Output = InspectPackageGraphToolOutput

    public static let identifier: AgentToolIdentifier =
        "inspect_package_graph"

    public static let description =
        "Inspect the SwiftPM package graph for the selected Swift package root."

    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public var execution: AgentToolExecutionContract {
        .targetable
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = input

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: name,
            risk: risk,
            usesCompilerProvider: false,
            summary:
                "Inspect SwiftPM package topology at the selected workspace location."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        _ = input

        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: name
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let graph = try await workspace.packageGraph()

        return .init(
            graph: graph
        )
    }
}

public struct FindSwiftDefinitionTool:
    AgentTool
{
    public typealias Input = SwiftSemanticPositionToolInput
    public typealias Output = SwiftSemanticLocationsToolOutput

    public static let identifier: AgentToolIdentifier =
        "find_swift_definition"

    public static let description =
        "Resolve compiler-semantic definitions for the Swift symbol at a source position."

    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public var execution: AgentToolExecutionContract {
        .targetable
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: name,
            risk: risk,
            path: input.path,
            summary:
                "Resolve Swift definition at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: name
        )
        let file = try execution.projectFile(
            input.path,
            toolName: name
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let values = try await workspace.definition(
            in: file,
            at: position
        )

        return locationOutput(
            path: input.path,
            values: values,
            limit: input.limit
        )
    }
}

public struct FindSwiftReferencesTool:
    AgentTool
{
    public typealias Input = SwiftSemanticReferencesToolInput
    public typealias Output = SwiftSemanticLocationsToolOutput

    public static let identifier: AgentToolIdentifier =
        "find_swift_references"

    public static let description =
        "Find compiler-semantic references to the Swift symbol at a source position."

    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public var execution: AgentToolExecutionContract {
        .targetable
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: name,
            risk: risk,
            path: input.path,
            summary:
                "Find Swift references at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: name
        )
        let file = try execution.projectFile(
            input.path,
            toolName: name
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let values = try await workspace.references(
            in: file,
            at: position,
            includeDeclaration:
                input.includeDeclaration
                    ?? true
        )

        return locationOutput(
            path: input.path,
            values: values,
            limit: input.limit
        )
    }
}

public struct FindSwiftImplementationsTool:
    AgentTool
{
    public typealias Input = SwiftSemanticPositionToolInput
    public typealias Output = SwiftSemanticLocationsToolOutput

    public static let identifier: AgentToolIdentifier =
        "find_swift_implementations"

    public static let description =
        "Find compiler-semantic implementations of the Swift declaration at a source position."

    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public var execution: AgentToolExecutionContract {
        .targetable
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: name,
            risk: risk,
            path: input.path,
            summary:
                "Find Swift implementations at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: name
        )
        let file = try execution.projectFile(
            input.path,
            toolName: name
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let values = try await workspace.implementations(
            in: file,
            at: position
        )

        return locationOutput(
            path: input.path,
            values: values,
            limit: input.limit
        )
    }
}

public struct InspectSwiftDiagnosticsTool:
    AgentTool
{
    public typealias Input = SwiftSemanticFileToolInput
    public typealias Output = InspectSwiftDiagnosticsToolOutput

    public static let identifier: AgentToolIdentifier =
        "inspect_swift_diagnostics"

    public static let description =
        "Inspect current compiler diagnostics for a Swift source file."

    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public var execution: AgentToolExecutionContract {
        .targetable
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: name,
            risk: risk,
            path: input.path,
            summary:
                "Inspect Swift compiler diagnostics for \(input.path)."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: name
        )
        let file = try execution.projectFile(
            input.path,
            toolName: name
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let values = try await workspace.diagnostics(
            for: file
        )
        let limit = SwiftSemanticToolSupport.limit(
            input.limit
        )
        let returned = Array(
            values.prefix(
                limit
            )
        )

        return .init(
            path: input.path,
            totalCount: values.count,
            returnedCount: returned.count,
            truncated: returned.count < values.count,
            diagnostics: returned
        )
    }
}

public struct SearchSwiftSymbolsTool:
    AgentTool
{
    public typealias Input = SwiftSemanticSymbolSearchToolInput
    public typealias Output = SearchSwiftSymbolsToolOutput

    public static let identifier: AgentToolIdentifier =
        "search_swift_symbols"

    public static let description =
        "Search the compiler-semantic Swift workspace index for symbols."

    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public var execution: AgentToolExecutionContract {
        .targetable
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: name,
            risk: risk,
            summary:
                "Search Swift compiler symbols matching '\(input.query)' at the selected workspace location."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: name
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let values = try await workspace.workspaceSymbols(
            matching: input.query
        )
        let limit = SwiftSemanticToolSupport.limit(
            input.limit
        )
        let returned = Array(
            values.prefix(
                limit
            )
        )

        return .init(
            query: input.query,
            totalCount: values.count,
            returnedCount: returned.count,
            truncated: returned.count < values.count,
            symbols: returned
        )
    }
}

public struct InspectSwiftSymbolTool:
    AgentTool
{
    public typealias Input = SwiftSemanticPositionToolInput
    public typealias Output = InspectSwiftSymbolToolOutput

    public static let identifier: AgentToolIdentifier =
        "inspect_swift_symbol"

    public static let description =
        "Inspect compiler-resolved Swift symbol identity, including USR data when available."

    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public var execution: AgentToolExecutionContract {
        .targetable
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: name,
            risk: risk,
            path: input.path,
            summary:
                "Inspect Swift symbol identity at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: name
        )
        let file = try execution.projectFile(
            input.path,
            toolName: name
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let values = try await workspace.symbolInfo(
            in: file,
            at: position
        )
        let limit = SwiftSemanticToolSupport.limit(
            input.limit
        )

        return .init(
            path: input.path,
            symbols: Array(
                values.prefix(
                    limit
                )
            )
        )
    }
}

public struct InspectSwiftHoverTool:
    AgentTool
{
    public typealias Input = SwiftSemanticPositionToolInput
    public typealias Output = InspectSwiftHoverToolOutput

    public static let identifier: AgentToolIdentifier =
        "inspect_swift_hover"

    public static let description =
        "Inspect compiler-generated Swift type, signature, and documentation hover information."

    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public var execution: AgentToolExecutionContract {
        .targetable
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: name,
            risk: risk,
            path: input.path,
            summary:
                "Inspect Swift hover information at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: name
        )
        let file = try execution.projectFile(
            input.path,
            toolName: name
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )

        return .init(
            path: input.path,
            hover: try await workspace.hover(
                in: file,
                at: position
            )
        )
    }
}

public struct InspectSwiftDocumentSymbolsTool:
    AgentTool
{
    public typealias Input = SwiftSemanticFileToolInput
    public typealias Output = InspectSwiftDocumentSymbolsToolOutput

    public static let identifier: AgentToolIdentifier =
        "inspect_swift_document_symbols"

    public static let description =
        "Inspect compiler-aware hierarchical symbols for one Swift source file."

    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public var execution: AgentToolExecutionContract {
        .targetable
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: name,
            risk: risk,
            path: input.path,
            summary:
                "Inspect compiler-aware Swift document symbols for \(input.path)."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: name
        )
        let file = try execution.projectFile(
            input.path,
            toolName: name
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let values = try await workspace.documentSymbols(
            for: file
        )
        let limit = SwiftSemanticToolSupport.limit(
            input.limit
        )
        let returned = Array(
            values.prefix(
                limit
            )
        )

        return .init(
            path: input.path,
            totalCount: values.count,
            returnedCount: returned.count,
            truncated: returned.count < values.count,
            symbols: returned
        )
    }
}

public struct InspectSwiftCallersTool:
    AgentTool
{
    public typealias Input = SwiftSemanticPositionToolInput
    public typealias Output = InspectSwiftCallersToolOutput

    public static let identifier: AgentToolIdentifier =
        "inspect_swift_callers"

    public static let description =
        "Inspect compiler-semantic callers of the Swift callable at a source position."

    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public var execution: AgentToolExecutionContract {
        .targetable
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: name,
            risk: risk,
            path: input.path,
            summary:
                "Inspect Swift callers at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: name
        )
        let file = try execution.projectFile(
            input.path,
            toolName: name
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let values = try await workspace.incomingCalls(
            in: file,
            at: position
        )
        let limit = SwiftSemanticToolSupport.limit(
            input.limit
        )
        let returned = Array(
            values.prefix(
                limit
            )
        )

        return .init(
            path: input.path,
            totalCount: values.count,
            returnedCount: returned.count,
            truncated: returned.count < values.count,
            calls: returned
        )
    }
}

public struct InspectSwiftCalleesTool:
    AgentTool
{
    public typealias Input = SwiftSemanticPositionToolInput
    public typealias Output = InspectSwiftCalleesToolOutput

    public static let identifier: AgentToolIdentifier =
        "inspect_swift_callees"

    public static let description =
        "Inspect compiler-semantic callees referenced by the Swift callable at a source position."

    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public var execution: AgentToolExecutionContract {
        .targetable
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: name,
            risk: risk,
            path: input.path,
            summary:
                "Inspect Swift callees at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: name
        )
        let file = try execution.projectFile(
            input.path,
            toolName: name
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let values = try await workspace.outgoingCalls(
            in: file,
            at: position
        )
        let limit = SwiftSemanticToolSupport.limit(
            input.limit
        )
        let returned = Array(
            values.prefix(
                limit
            )
        )

        return .init(
            path: input.path,
            totalCount: values.count,
            returnedCount: returned.count,
            truncated: returned.count < values.count,
            calls: returned
        )
    }
}

public struct InspectSwiftSupertypesTool:
    AgentTool
{
    public typealias Input = SwiftSemanticPositionToolInput
    public typealias Output = InspectSwiftTypeHierarchyToolOutput

    public static let identifier: AgentToolIdentifier =
        "inspect_swift_supertypes"

    public static let description =
        "Inspect direct compiler-semantic supertypes of the Swift type at a source position."

    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public var execution: AgentToolExecutionContract {
        .targetable
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: name,
            risk: risk,
            path: input.path,
            summary:
                "Inspect Swift supertypes at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: name
        )
        let file = try execution.projectFile(
            input.path,
            toolName: name
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let values = try await workspace.supertypes(
            in: file,
            at: position
        )

        return typeHierarchyOutput(
            path: input.path,
            values: values,
            limit: input.limit
        )
    }
}

public struct InspectSwiftSubtypesTool:
    AgentTool
{
    public typealias Input = SwiftSemanticPositionToolInput
    public typealias Output = InspectSwiftTypeHierarchyToolOutput

    public static let identifier: AgentToolIdentifier =
        "inspect_swift_subtypes"

    public static let description =
        "Inspect direct compiler-semantic subtypes of the Swift type at a source position."

    public static let risk: ActionRisk =
        .privileged

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public var execution: AgentToolExecutionContract {
        .targetable
    }

    public init() {}

    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: name,
            risk: risk,
            path: input.path,
            summary:
                "Inspect Swift subtypes at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: name
        )
        let file = try execution.projectFile(
            input.path,
            toolName: name
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: name
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let values = try await workspace.subtypes(
            in: file,
            at: position
        )

        return typeHierarchyOutput(
            path: input.path,
            values: values,
            limit: input.limit
        )
    }
}

private func locationOutput(
    path: String,
    values: [SwiftSemanticLocation],
    limit requestedLimit: Int?
) -> SwiftSemanticLocationsToolOutput {
    let limit = SwiftSemanticToolSupport.limit(
        requestedLimit
    )
    let returned = Array(
        values.prefix(
            limit
        )
    )

    return .init(
        path: path,
        totalCount: values.count,
        returnedCount: returned.count,
        truncated: returned.count < values.count,
        locations: returned
    )
}

private func typeHierarchyOutput(
    path: String,
    values: [SwiftSemanticTypeHierarchyItem],
    limit requestedLimit: Int?
) -> InspectSwiftTypeHierarchyToolOutput {
    let limit = SwiftSemanticToolSupport.limit(
        requestedLimit
    )
    let returned = Array(
        values.prefix(
            limit
        )
    )

    return .init(
        path: path,
        totalCount: values.count,
        returnedCount: returned.count,
        truncated: returned.count < values.count,
        types: returned
    )
}
