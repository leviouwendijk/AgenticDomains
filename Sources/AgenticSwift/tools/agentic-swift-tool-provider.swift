import Agentic

public struct AgenticSwiftToolProvider: AgentToolProvider {
    public init() {}

    public func registerTools(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register(SwiftLang.Tools.InspectArchitecture())
        try registry.register(SwiftLang.Tools.SearchArchitecture())
        try registry.register(SwiftLang.Tools.InspectArchitectureSymbol())
        try registry.register(SwiftLang.Tools.InspectArchitectureRelationships())
        try registry.register(SwiftLang.Tools.InspectRepositoryArchitecture())
        try registry.register(SwiftLang.Tools.InspectPackageGraph())
        try registry.register(SwiftLang.Tools.FindDefinition())
        try registry.register(SwiftLang.Tools.FindReferences())
        try registry.register(SwiftLang.Tools.FindImplementations())
        try registry.register(SwiftLang.Tools.InspectDiagnostics())
        try registry.register(SwiftLang.Tools.SearchSymbols())
        try registry.register(SwiftLang.Tools.InspectSymbol())
        try registry.register(SwiftLang.Tools.InspectHover())
        try registry.register(SwiftLang.Tools.InspectDocumentSymbols())
        try registry.register(SwiftLang.Tools.InspectCallers())
        try registry.register(SwiftLang.Tools.InspectCallees())
        try registry.register(SwiftLang.Tools.InspectSupertypes())
        try registry.register(SwiftLang.Tools.InspectSubtypes())
        try registry.register(SwiftDeployedProductsTool())
        try registry.register(SwiftCrashReportsTool())
        try registry.register(SwiftPackageCyclesTool())
        try registry.register(ReadSwiftSymbolTool())
        try registry.register(SwiftVersionTool())
        try registry.register(SwiftCleanTool())
        try registry.register(SwiftResolveTool())
        try registry.register(SwiftLang.Tools.PackageUpdate())
        try registry.register(SwiftBuildObjectInitTool())
        try registry.register(SwiftBuildObjectModernizeTool())
        try registry.register(SwiftBuildLibraryTool())
        try registry.register(SwiftDeployTool())
        try registry.register(SwiftLang.Tools.LintSource())
        try registry.register(SwiftLang.Tools.LintFiles())
        try registry.register(SwiftLang.Tools.LintPackage())
        try registry.register(ReadSwiftStructureTool())
        try registry.register(SwiftParseTool())
        try registry.register(SwiftKillSwiftPMTool())
        try registry.register(ListSwiftSymbolsTool())
        try registry.register(SwiftLang.Tools.RunProduct())
        try registry.register(SwiftIncrementVersionTool())
        try registry.register(SwiftLang.Tools.Build())
        try registry.register(SwiftRemoveDeployedTool())
        try registry.register(SwiftAppBundleTool())
        try registry.register(SwiftExecutableProductsTool())
    }
}
