import Agentic

public struct AgenticSwiftToolSet: AgentToolSet {
    public init() {}

    public func register(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register(
            [
                ReadSwiftStructureTool(),
                ListSwiftSymbolsTool(),
                ReadSwiftSymbolTool(),
            ]
        )
    }
}
