import Agentic

public struct AgenticSwiftProgramSet:
    ProgramSet,
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
