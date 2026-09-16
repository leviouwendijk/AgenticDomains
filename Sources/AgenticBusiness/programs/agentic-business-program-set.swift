import AgenticPrograms

public struct AgenticBusinessProgramSet:
    AgentProgramSet,
    Sendable
{
    public init() {}

    public func register(
        into registry: inout ProgramRegistry
    ) throws {
        try registry.register(
            PrepareBusinessReplyProgram()
        )
    }
}
