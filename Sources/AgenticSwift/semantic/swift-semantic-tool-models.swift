import Foundation
import Schema
import SchemaMacros
import SwiftSemantics

@JSONSchema
public struct SwiftSemanticPositionToolInput:
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
public struct SwiftSemanticReferencesToolInput:
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
public struct SwiftSemanticFileToolInput:
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
public struct SwiftSemanticSymbolSearchToolInput:
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

public struct SwiftSemanticLocationsToolOutput:
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

public struct InspectSwiftDiagnosticsToolOutput:
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

public struct SearchSwiftSymbolsToolOutput:
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

public struct InspectSwiftSymbolToolOutput:
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

public struct InspectSwiftHoverToolOutput:
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

public struct InspectSwiftDocumentSymbolsToolOutput:
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

public struct InspectSwiftCallersToolOutput:
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

public struct InspectSwiftCalleesToolOutput:
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

public struct InspectSwiftTypeHierarchyToolOutput:
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

public struct InspectPackageGraphToolOutput:
    Sendable,
    Codable
{
    public struct Platform:
        Sendable,
        Codable
    {
        public let name: String
        public let version: String
    }

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

    public struct PackageDependency:
        Sendable,
        Codable
    {
        public let sourceIdentity: String
        public let targetIdentity: String
    }

    public struct DeclaredPackageDependency:
        Sendable,
        Codable
    {
        public let kind: String
        public let identity: String?
        public let location: String?
    }

    public struct Product:
        Sendable,
        Codable
    {
        public let name: String
        public let kind: String
        public let targets: [String]
    }

    public struct TargetDependency:
        Sendable,
        Codable
    {
        public let kind: String
        public let name: String
        public let package: String?
    }

    public struct Target:
        Sendable,
        Codable
    {
        public let name: String
        public let type: String
        public let path: String?
        public let dependencies: [TargetDependency]
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
