import Agentic

public struct BusinessProgramSet:
    ProgramSet,
    Sendable
{
    public init() {}

    public func register(
        into registry: inout ProgramRegistry
    ) throws {
        try registry.register(
            Business.Programs.PrepareReply()
        )
    }
}
