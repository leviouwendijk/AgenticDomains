import AgenticPrograms

public struct PlanSwiftChangeProgram:
    AgentProgram,
    Sendable
{
    public typealias Input = SwiftChangeContext
    public typealias Output = SwiftChangeAssessment

    public static let understandingSite: AgentInferenceSiteIdentifier =
        "understand_change"

    public static let planningSite: AgentInferenceSiteIdentifier =
        "plan_changes"

    public static let descriptor = AgentProgramDescriptor(
        identifier: "swift.plan_change",
        title: "Plan Swift Change",
        summary: "Understand supplied Swift change evidence through one typed inference, then feed that typed understanding into a second inference that produces a bounded implementation and verification plan.",
        tags: [
            "swift",
            "planning",
            "inference",
            "composition",
        ]
    )

    public init() {}

    public func run(
        _ input: Input,
        in context: AgentProgramContext
    ) async throws -> Output {
        let understanding = try await context.infer(
            UnderstandSwiftChange.self,
            at: Self.understandingSite,
            input: input
        )

        let plan = try await context.infer(
            PlanSwiftChange.self,
            at: Self.planningSite,
            input: SwiftChangePlanningInput(
                objective: input.objective,
                constraints: input.constraints,
                understanding: understanding
            )
        )

        return SwiftChangeAssessment(
            understanding: understanding,
            plan: plan
        )
    }
}
