import Agentic

public struct AgenticSwiftToolProvider: AgentToolProvider {
    public init() {}

    public func registerTools(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register(
            SwiftLang.Tools.InspectArchitecture(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.SearchArchitecture(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.InspectArchitectureSymbol(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.InspectArchitectureRelationships(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.InspectRepositoryArchitecture(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.InspectPackageGraph(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.FindDefinition(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.FindReferences(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.FindImplementations(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.InspectDiagnostics(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.SearchSymbols(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.InspectSymbol(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.InspectHover(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.InspectDocumentSymbols(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.InspectCallers(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.InspectCallees(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.InspectSupertypes(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.InspectSubtypes(),
            execution: .targetable
        )
        try registry.register(SwiftDeployedProductsTool())
        try registry.register(SwiftCrashReportsTool())
        try registry.register(
            SwiftPackageCyclesTool(),
            execution: .targetable
        )
        try registry.register(ReadSwiftSymbolTool())
        try registry.register(
            SwiftVersionTool(),
            execution: .targetable
        )
        try registry.register(
            SwiftCleanTool(),
            execution: .targetable
        )
        try registry.register(
            SwiftResolveTool(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.PackageUpdate(),
            execution: .targetable
        )
        try registry.register(
            SwiftBuildObjectInitTool(),
            execution: .targetable
        )
        try registry.register(
            SwiftBuildObjectModernizeTool(),
            execution: .targetable
        )
        try registry.register(
            SwiftBuildLibraryTool(),
            execution: .targetable
        )
        try registry.register(
            SwiftDeployTool(),
            execution: .targetable
        )
        try registry.register(SwiftLang.Tools.LintSource())
        try registry.register(SwiftLang.Tools.LintFiles())
        try registry.register(
            SwiftLang.Tools.LintPackage(),
            execution: .targetable
        )
        try registry.register(ReadSwiftStructureTool())
        try registry.register(SwiftParseTool())
        try registry.register(
            SwiftKillSwiftPMTool(),
            execution: .targetable
        )
        try registry.register(ListSwiftSymbolsTool())
        try registry.register(
            SwiftLang.Tools.RunProduct(),
            execution: .targetable
        )
        try registry.register(
            SwiftIncrementVersionTool(),
            execution: .targetable
        )
        try registry.register(
            SwiftLang.Tools.Build(),
            execution: .targetable
        )
        try registry.register(SwiftRemoveDeployedTool())
        try registry.register(
            SwiftAppBundleTool(),
            execution: .targetable
        )
        try registry.register(
            SwiftExecutableProductsTool(),
            execution: .targetable
        )
    }
}
