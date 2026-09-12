import AgenticPrograms

public struct AgenticSwiftProgramSet:
    AgentProgramSet,
    Sendable
{
    public init() {}

    public func register(
        into registry: inout ProgramRegistry
    ) throws {
        try registry.register(
            PlanSwiftChangeProgram()
        )
    }
}
