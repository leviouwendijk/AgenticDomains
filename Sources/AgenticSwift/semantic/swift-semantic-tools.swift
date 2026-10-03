import Agentic
import Macros
import Schema
import Workspace
import SwiftSemantics

public struct InspectPackageGraphTool:
    Tool
{
    @JSONSchema
    public struct Input:
        Codable,
        Sendable
    {
        public init() {}
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable
    {
        @JSONSchema
        public struct Platform:
            Sendable,
            Codable
        {
            public let name: String
            public let version: String
        }

        @JSONSchema
        public struct Package:
            Sendable,
            Codable
        {
            public let identity: String
            public let name: String
            public let location: String?
            public let version: String?
            public let path: String?
        }

        @JSONSchema
        public struct PackageDependency:
            Sendable,
            Codable
        {
            public let sourceIdentity: String
            public let targetIdentity: String
        }

        @JSONSchema
        public struct DeclaredPackageDependency:
            Sendable,
            Codable
        {
            public let kind: String
            public let identity: String?
            public let location: String?
        }

        @JSONSchema
        public struct Product:
            Sendable,
            Codable
        {
            public let name: String
            public let kind: String
            public let targets: [String]
        }

        @JSONSchema
        public struct Target:
            Sendable,
            Codable
        {
            @JSONSchema
            public struct Dependency:
                Sendable,
                Codable
            {
                public let kind: String
                public let name: String
                public let package: String?
            }
            public let name: String
            public let type: String
            public let path: String?
            public let dependencies: [Dependency]
        }

        public let rootIdentity: String
        public let rootName: String
        public let toolsVersion: String?
        public let platforms: [Platform]
        public let packages: [Package]
        public let packageDependencies: [PackageDependency]
        public let declaredPackageDependencies: [DeclaredPackageDependency]
        public let products: [Product]
        public let targets: [Target]

        public init(
            graph: SwiftSemanticPackageGraph
        ) {
            rootIdentity = graph.rootIdentity
            rootName = graph.rootName
            toolsVersion = graph.toolsVersion

            platforms = graph.platforms.map {
                .init(
                    name: $0.name,
                    version: $0.version
                )
            }

            packages = graph.packages.map {
                .init(
                    identity: $0.identity,
                    name: $0.name,
                    location: $0.location,
                    version: $0.version,
                    path: $0.path
                )
            }

            packageDependencies = graph.packageDependencies.map {
                .init(
                    sourceIdentity: $0.sourceIdentity,
                    targetIdentity: $0.targetIdentity
                )
            }

            declaredPackageDependencies = graph.declaredPackageDependencies.map {
                .init(
                    kind: $0.kind.rawValue,
                    identity: $0.identity,
                    location: $0.location
                )
            }

            products = graph.products.map {
                .init(
                    name: $0.name,
                    kind: $0.kind.rawValue,
                    targets: $0.targets
                )
            }

            targets = graph.targets.map { target in
                .init(
                    name: target.name,
                    type: target.type,
                    path: target.path,
                    dependencies: target.dependencies.map {
                        .init(
                            kind: $0.kind.rawValue,
                            name: $0.name,
                            package: $0.package
                        )
                    }
                )
            }
        }
    }

public static let identifier: ToolIdentifier =
        "inspect_package_graph"

    public static let description =
        "Inspect the SwiftPM package graph for the selected Swift package root."

    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = input

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            risk: risk,
            usesCompilerProvider: false,
            summary:
                "Inspect SwiftPM package topology at the selected workspace location."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        _ = input

        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
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
    Tool
{
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Swift source path relative to the selected Swift package root.
        public let path: String

        /// One-based source line.
        public let line: Int

        /// One-based UTF-16 code-unit column used by compiler semantics.
        public let utf16Column: Int

        /// Optional maximum number of returned items.
        public let limit: Int?

        public init(
            path: String,
            line: Int,
            utf16Column: Int,
            limit: Int? = nil
        ) {
            self.path = path
            self.line = line
            self.utf16Column = utf16Column
            self.limit = limit
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable
    {
        public let path: String
        public let totalCount: Int
        public let returnedCount: Int
        public let truncated: Bool
        public let locations: [SwiftSemanticLocation]

        public init(
            path: String,
            totalCount: Int,
            returnedCount: Int,
            truncated: Bool,
            locations: [SwiftSemanticLocation]
        ) {
            self.path = path
            self.totalCount = totalCount
            self.returnedCount = returnedCount
            self.truncated = truncated
            self.locations = locations
        }
    }

public static let identifier: ToolIdentifier =
        "find_swift_definition"

    public static let description =
        "Resolve compiler-semantic definitions for the Swift symbol at a source position."

    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            risk: risk,
            path: input.path,
            summary:
                "Resolve Swift definition at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let file = try execution.projectFile(
            input.path,
            toolName: Self.definition.identifier.rawValue
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let values = try await workspace.definition(
            in: file,
            at: position
        )

        let bounded = boundedLocations(
            values: values,
            limit: input.limit
        )

        return .init(
            path: input.path,
            totalCount: values.count,
            returnedCount: bounded.count,
            truncated: bounded.count < values.count,
            locations: bounded
        )
    }
}

public struct FindSwiftReferencesTool:
    Tool
{
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        public let path: String
        public let line: Int
        public let utf16Column: Int

        /// Whether the declaration itself is included in returned references.
        public let includeDeclaration: Bool?

        public let limit: Int?

        public init(
            path: String,
            line: Int,
            utf16Column: Int,
            includeDeclaration: Bool? = nil,
            limit: Int? = nil
        ) {
            self.path = path
            self.line = line
            self.utf16Column = utf16Column
            self.includeDeclaration = includeDeclaration
            self.limit = limit
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable
    {
        public let path: String
        public let totalCount: Int
        public let returnedCount: Int
        public let truncated: Bool
        public let locations: [SwiftSemanticLocation]

        public init(
            path: String,
            totalCount: Int,
            returnedCount: Int,
            truncated: Bool,
            locations: [SwiftSemanticLocation]
        ) {
            self.path = path
            self.totalCount = totalCount
            self.returnedCount = returnedCount
            self.truncated = truncated
            self.locations = locations
        }
    }

public static let identifier: ToolIdentifier =
        "find_swift_references"

    public static let description =
        "Find compiler-semantic references to the Swift symbol at a source position."

    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            risk: risk,
            path: input.path,
            summary:
                "Find Swift references at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let file = try execution.projectFile(
            input.path,
            toolName: Self.definition.identifier.rawValue
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
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

        let bounded = boundedLocations(
            values: values,
            limit: input.limit
        )

        return .init(
            path: input.path,
            totalCount: values.count,
            returnedCount: bounded.count,
            truncated: bounded.count < values.count,
            locations: bounded
        )
    }
}

public struct FindSwiftImplementationsTool:
    Tool
{
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Swift source path relative to the selected Swift package root.
        public let path: String

        /// One-based source line.
        public let line: Int

        /// One-based UTF-16 code-unit column used by compiler semantics.
        public let utf16Column: Int

        /// Optional maximum number of returned items.
        public let limit: Int?

        public init(
            path: String,
            line: Int,
            utf16Column: Int,
            limit: Int? = nil
        ) {
            self.path = path
            self.line = line
            self.utf16Column = utf16Column
            self.limit = limit
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable
    {
        public let path: String
        public let totalCount: Int
        public let returnedCount: Int
        public let truncated: Bool
        public let locations: [SwiftSemanticLocation]

        public init(
            path: String,
            totalCount: Int,
            returnedCount: Int,
            truncated: Bool,
            locations: [SwiftSemanticLocation]
        ) {
            self.path = path
            self.totalCount = totalCount
            self.returnedCount = returnedCount
            self.truncated = truncated
            self.locations = locations
        }
    }

public static let identifier: ToolIdentifier =
        "find_swift_implementations"

    public static let description =
        "Find compiler-semantic implementations of the Swift declaration at a source position."

    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            risk: risk,
            path: input.path,
            summary:
                "Find Swift implementations at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let file = try execution.projectFile(
            input.path,
            toolName: Self.definition.identifier.rawValue
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let values = try await workspace.implementations(
            in: file,
            at: position
        )

        let bounded = boundedLocations(
            values: values,
            limit: input.limit
        )

        return .init(
            path: input.path,
            totalCount: values.count,
            returnedCount: bounded.count,
            truncated: bounded.count < values.count,
            locations: bounded
        )
    }
}

public struct InspectSwiftDiagnosticsTool:
    Tool
{
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Swift source path relative to the selected Swift package root.
        public let path: String

        /// Optional maximum number of returned items.
        public let limit: Int?

        public init(
            path: String,
            limit: Int? = nil
        ) {
            self.path = path
            self.limit = limit
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable
    {
        public let path: String
        public let totalCount: Int
        public let returnedCount: Int
        public let truncated: Bool
        public let diagnostics: [SwiftSemanticDiagnostic]

        public init(
            path: String,
            totalCount: Int,
            returnedCount: Int,
            truncated: Bool,
            diagnostics: [SwiftSemanticDiagnostic]
        ) {
            self.path = path
            self.totalCount = totalCount
            self.returnedCount = returnedCount
            self.truncated = truncated
            self.diagnostics = diagnostics
        }
    }

public static let identifier: ToolIdentifier =
        "inspect_swift_diagnostics"

    public static let description =
        "Inspect current compiler diagnostics for a Swift source file."

    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            risk: risk,
            path: input.path,
            summary:
                "Inspect Swift compiler diagnostics for \(input.path)."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let file = try execution.projectFile(
            input.path,
            toolName: Self.definition.identifier.rawValue
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
    Tool
{
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        public let query: String
        public let limit: Int?

        public init(
            query: String,
            limit: Int? = nil
        ) {
            self.query = query
            self.limit = limit
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable
    {
        public let query: String
        public let totalCount: Int
        public let returnedCount: Int
        public let truncated: Bool
        public let symbols: [SwiftSemanticWorkspaceSymbol]

        public init(
            query: String,
            totalCount: Int,
            returnedCount: Int,
            truncated: Bool,
            symbols: [SwiftSemanticWorkspaceSymbol]
        ) {
            self.query = query
            self.totalCount = totalCount
            self.returnedCount = returnedCount
            self.truncated = truncated
            self.symbols = symbols
        }
    }

public static let identifier: ToolIdentifier =
        "search_swift_symbols"

    public static let description =
        "Search the compiler-semantic Swift workspace index for symbols."

    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            risk: risk,
            summary:
                "Search Swift compiler symbols matching '\(input.query)' at the selected workspace location."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
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
    Tool
{
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Swift source path relative to the selected Swift package root.
        public let path: String

        /// One-based source line.
        public let line: Int

        /// One-based UTF-16 code-unit column used by compiler semantics.
        public let utf16Column: Int

        /// Optional maximum number of returned items.
        public let limit: Int?

        public init(
            path: String,
            line: Int,
            utf16Column: Int,
            limit: Int? = nil
        ) {
            self.path = path
            self.line = line
            self.utf16Column = utf16Column
            self.limit = limit
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable
    {
        public let path: String
        public let symbols: [SwiftSemanticCompilerSymbol]

        public init(
            path: String,
            symbols: [SwiftSemanticCompilerSymbol]
        ) {
            self.path = path
            self.symbols = symbols
        }
    }

public static let identifier: ToolIdentifier =
        "inspect_swift_symbol"

    public static let description =
        "Inspect compiler-resolved Swift symbol identity, including USR data when available."

    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            risk: risk,
            path: input.path,
            summary:
                "Inspect Swift symbol identity at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let file = try execution.projectFile(
            input.path,
            toolName: Self.definition.identifier.rawValue
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
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
    Tool
{
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Swift source path relative to the selected Swift package root.
        public let path: String

        /// One-based source line.
        public let line: Int

        /// One-based UTF-16 code-unit column used by compiler semantics.
        public let utf16Column: Int

        /// Optional maximum number of returned items.
        public let limit: Int?

        public init(
            path: String,
            line: Int,
            utf16Column: Int,
            limit: Int? = nil
        ) {
            self.path = path
            self.line = line
            self.utf16Column = utf16Column
            self.limit = limit
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable
    {
        public let path: String
        public let hover: SwiftSemanticHover?

        public init(
            path: String,
            hover: SwiftSemanticHover?
        ) {
            self.path = path
            self.hover = hover
        }
    }

public static let identifier: ToolIdentifier =
        "inspect_swift_hover"

    public static let description =
        "Inspect compiler-generated Swift type, signature, and documentation hover information."

    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            risk: risk,
            path: input.path,
            summary:
                "Inspect Swift hover information at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let file = try execution.projectFile(
            input.path,
            toolName: Self.definition.identifier.rawValue
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
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
    Tool
{
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Swift source path relative to the selected Swift package root.
        public let path: String

        /// Optional maximum number of returned items.
        public let limit: Int?

        public init(
            path: String,
            limit: Int? = nil
        ) {
            self.path = path
            self.limit = limit
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable
    {
        public let path: String
        public let totalCount: Int
        public let returnedCount: Int
        public let truncated: Bool
        public let symbols: [SwiftSemanticDocumentSymbol]

        public init(
            path: String,
            totalCount: Int,
            returnedCount: Int,
            truncated: Bool,
            symbols: [SwiftSemanticDocumentSymbol]
        ) {
            self.path = path
            self.totalCount = totalCount
            self.returnedCount = returnedCount
            self.truncated = truncated
            self.symbols = symbols
        }
    }

public static let identifier: ToolIdentifier =
        "inspect_swift_document_symbols"

    public static let description =
        "Inspect compiler-aware hierarchical symbols for one Swift source file."

    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            risk: risk,
            path: input.path,
            summary:
                "Inspect compiler-aware Swift document symbols for \(input.path)."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let file = try execution.projectFile(
            input.path,
            toolName: Self.definition.identifier.rawValue
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
    Tool
{
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Swift source path relative to the selected Swift package root.
        public let path: String

        /// One-based source line.
        public let line: Int

        /// One-based UTF-16 code-unit column used by compiler semantics.
        public let utf16Column: Int

        /// Optional maximum number of returned items.
        public let limit: Int?

        public init(
            path: String,
            line: Int,
            utf16Column: Int,
            limit: Int? = nil
        ) {
            self.path = path
            self.line = line
            self.utf16Column = utf16Column
            self.limit = limit
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable
    {
        public let path: String
        public let totalCount: Int
        public let returnedCount: Int
        public let truncated: Bool
        public let calls: [SwiftSemanticIncomingCall]

        public init(
            path: String,
            totalCount: Int,
            returnedCount: Int,
            truncated: Bool,
            calls: [SwiftSemanticIncomingCall]
        ) {
            self.path = path
            self.totalCount = totalCount
            self.returnedCount = returnedCount
            self.truncated = truncated
            self.calls = calls
        }
    }

public static let identifier: ToolIdentifier =
        "inspect_swift_callers"

    public static let description =
        "Inspect compiler-semantic callers of the Swift callable at a source position."

    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            risk: risk,
            path: input.path,
            summary:
                "Inspect Swift callers at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let file = try execution.projectFile(
            input.path,
            toolName: Self.definition.identifier.rawValue
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
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
    Tool
{
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Swift source path relative to the selected Swift package root.
        public let path: String

        /// One-based source line.
        public let line: Int

        /// One-based UTF-16 code-unit column used by compiler semantics.
        public let utf16Column: Int

        /// Optional maximum number of returned items.
        public let limit: Int?

        public init(
            path: String,
            line: Int,
            utf16Column: Int,
            limit: Int? = nil
        ) {
            self.path = path
            self.line = line
            self.utf16Column = utf16Column
            self.limit = limit
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable
    {
        public let path: String
        public let totalCount: Int
        public let returnedCount: Int
        public let truncated: Bool
        public let calls: [SwiftSemanticOutgoingCall]

        public init(
            path: String,
            totalCount: Int,
            returnedCount: Int,
            truncated: Bool,
            calls: [SwiftSemanticOutgoingCall]
        ) {
            self.path = path
            self.totalCount = totalCount
            self.returnedCount = returnedCount
            self.truncated = truncated
            self.calls = calls
        }
    }

public static let identifier: ToolIdentifier =
        "inspect_swift_callees"

    public static let description =
        "Inspect compiler-semantic callees referenced by the Swift callable at a source position."

    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            risk: risk,
            path: input.path,
            summary:
                "Inspect Swift callees at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let file = try execution.projectFile(
            input.path,
            toolName: Self.definition.identifier.rawValue
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
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
    Tool
{
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Swift source path relative to the selected Swift package root.
        public let path: String

        /// One-based source line.
        public let line: Int

        /// One-based UTF-16 code-unit column used by compiler semantics.
        public let utf16Column: Int

        /// Optional maximum number of returned items.
        public let limit: Int?

        public init(
            path: String,
            line: Int,
            utf16Column: Int,
            limit: Int? = nil
        ) {
            self.path = path
            self.line = line
            self.utf16Column = utf16Column
            self.limit = limit
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable
    {
        public let path: String
        public let totalCount: Int
        public let returnedCount: Int
        public let truncated: Bool
        public let types: [SwiftSemanticTypeHierarchyItem]

        public init(
            path: String,
            totalCount: Int,
            returnedCount: Int,
            truncated: Bool,
            types: [SwiftSemanticTypeHierarchyItem]
        ) {
            self.path = path
            self.totalCount = totalCount
            self.returnedCount = returnedCount
            self.truncated = truncated
            self.types = types
        }
    }

public static let identifier: ToolIdentifier =
        "inspect_swift_supertypes"

    public static let description =
        "Inspect direct compiler-semantic supertypes of the Swift type at a source position."

    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            risk: risk,
            path: input.path,
            summary:
                "Inspect Swift supertypes at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let file = try execution.projectFile(
            input.path,
            toolName: Self.definition.identifier.rawValue
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let values = try await workspace.supertypes(
            in: file,
            at: position
        )

        let bounded = boundedTypeHierarchy(
            values: values,
            limit: input.limit
        )

        return .init(
            path: input.path,
            totalCount: values.count,
            returnedCount: bounded.count,
            truncated: bounded.count < values.count,
            types: bounded
        )
    }
}

public struct InspectSwiftSubtypesTool:
    Tool
{
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Swift source path relative to the selected Swift package root.
        public let path: String

        /// One-based source line.
        public let line: Int

        /// One-based UTF-16 code-unit column used by compiler semantics.
        public let utf16Column: Int

        /// Optional maximum number of returned items.
        public let limit: Int?

        public init(
            path: String,
            line: Int,
            utf16Column: Int,
            limit: Int? = nil
        ) {
            self.path = path
            self.line = line
            self.utf16Column = utf16Column
            self.limit = limit
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable
    {
        public let path: String
        public let totalCount: Int
        public let returnedCount: Int
        public let truncated: Bool
        public let types: [SwiftSemanticTypeHierarchyItem]

        public init(
            path: String,
            totalCount: Int,
            returnedCount: Int,
            truncated: Bool,
            types: [SwiftSemanticTypeHierarchyItem]
        ) {
            self.path = path
            self.totalCount = totalCount
            self.returnedCount = returnedCount
            self.truncated = truncated
            self.types = types
        }
    }

public static let identifier: ToolIdentifier =
        "inspect_swift_subtypes"

    public static let description =
        "Inspect direct compiler-semantic subtypes of the Swift type at a source position."

    public static let risk: ActionRisk =
        .privileged

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
        )

        return try SwiftSemanticToolSupport.preflight(
            context: context,
            toolName: Self.definition.identifier.rawValue,
            risk: risk,
            path: input.path,
            summary:
                "Inspect Swift subtypes at \(input.path):\(input.line):\(input.utf16Column)."
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let file = try execution.projectFile(
            input.path,
            toolName: Self.definition.identifier.rawValue
        )
        let position = try SwiftSemanticToolSupport.position(
            line: input.line,
            utf16Column: input.utf16Column,
            toolName: Self.definition.identifier.rawValue
        )
        let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
            for: execution
        )
        let values = try await workspace.subtypes(
            in: file,
            at: position
        )

        let bounded = boundedTypeHierarchy(
            values: values,
            limit: input.limit
        )

        return .init(
            path: input.path,
            totalCount: values.count,
            returnedCount: bounded.count,
            truncated: bounded.count < values.count,
            types: bounded
        )
    }
}

private func boundedLocations(
    values: [SwiftSemanticLocation],
    limit requestedLimit: Int?
) -> [SwiftSemanticLocation] {
    let limit = SwiftSemanticToolSupport.limit(
        requestedLimit
    )

    return Array(
        values.prefix(
            limit
        )
    )
}

private func boundedTypeHierarchy(
    values: [SwiftSemanticTypeHierarchyItem],
    limit requestedLimit: Int?
) -> [SwiftSemanticTypeHierarchyItem] {
    let limit = SwiftSemanticToolSupport.limit(
        requestedLimit
    )

    return Array(
        values.prefix(
            limit
        )
    )
}
