import AgenticExecution

public struct AgenticSwiftToolSet: AgentToolSet {
    public init() {}

    public func register(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register {
            ReadSwiftStructureTool()
            ListSwiftSymbolsTool()
            ReadSwiftSymbolTool()

            InspectPackageGraphTool()
            FindSwiftDefinitionTool()
            FindSwiftReferencesTool()
            FindSwiftImplementationsTool()
            InspectSwiftDiagnosticsTool()
            SearchSwiftSymbolsTool()
            InspectSwiftSymbolTool()
            InspectSwiftHoverTool()
            InspectSwiftDocumentSymbolsTool()
            InspectSwiftCallersTool()
            InspectSwiftCalleesTool()
            InspectSwiftSupertypesTool()
            InspectSwiftSubtypesTool()

            SwiftExecutableProductsTool()
            SwiftParseTool()
            SwiftUpdateTool()
            SwiftResolveTool()
            SwiftBuildTool()
            SwiftCleanTool()
            SwiftVersionTool()
            SwiftDeployedProductsTool()
            SwiftRemoveDeployedTool()
            SwiftIncrementVersionTool()
            SwiftKillSwiftPMTool()
            SwiftBuildLibraryTool()
            SwiftBuildObjectInitTool()
            SwiftBuildObjectModernizeTool()
            SwiftAppBundleTool()
            SwiftDeployTool()
            SwiftRunProductTool()
        }
    }
}
