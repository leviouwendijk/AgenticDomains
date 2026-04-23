import Agentic

public struct AgenticSwiftToolProvider: AgentToolProvider {
    public init() {}

    public func registerTools(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register(
            AgenticSwiftToolSet()
        )
    }
}
