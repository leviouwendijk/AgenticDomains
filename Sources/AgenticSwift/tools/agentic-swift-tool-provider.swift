import Agentic

public struct AgenticSwiftToolProvider: AgentToolProvider {
    public init() {}

    public func registerTools(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register(
            InspectSwiftArchitectureTool(),
            execution: .targetable
        )
        try registry.register(
            SearchSwiftArchitectureTool(),
            execution: .targetable
        )
        try registry.register(
            InspectSwiftArchitectureSymbolTool(),
            execution: .targetable
        )
        try registry.register(
            InspectSwiftArchitectureRelationshipsTool(),
            execution: .targetable
        )
        try registry.register(
            InspectSwiftRepositoryArchitectureTool(),
            execution: .targetable
        )
        try registry.register(
            InspectPackageGraphTool(),
            execution: .targetable
        )
        try registry.register(
            FindSwiftDefinitionTool(),
            execution: .targetable
        )
        try registry.register(
            FindSwiftReferencesTool(),
            execution: .targetable
        )
        try registry.register(
            FindSwiftImplementationsTool(),
            execution: .targetable
        )
        try registry.register(
            InspectSwiftDiagnosticsTool(),
            execution: .targetable
        )
        try registry.register(
            SearchSwiftSymbolsTool(),
            execution: .targetable
        )
        try registry.register(
            InspectSwiftSymbolTool(),
            execution: .targetable
        )
        try registry.register(
            InspectSwiftHoverTool(),
            execution: .targetable
        )
        try registry.register(
            InspectSwiftDocumentSymbolsTool(),
            execution: .targetable
        )
        try registry.register(
            InspectSwiftCallersTool(),
            execution: .targetable
        )
        try registry.register(
            InspectSwiftCalleesTool(),
            execution: .targetable
        )
        try registry.register(
            InspectSwiftSupertypesTool(),
            execution: .targetable
        )
        try registry.register(
            InspectSwiftSubtypesTool(),
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
            SwiftUpdateTool(),
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
        try registry.register(LintSwiftSourceTool())
        try registry.register(LintSwiftFilesTool())
        try registry.register(
            LintSwiftPackageTool(),
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
            SwiftRunProductTool(),
            execution: .targetable
        )
        try registry.register(
            SwiftIncrementVersionTool(),
            execution: .targetable
        )
        try registry.register(
            SwiftBuildTool(),
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
