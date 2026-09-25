import Agentic

@Program
public struct PlanSwiftChangeProgram {
    public typealias Input = SwiftChangeContext
    public typealias Output = SwiftChangeAssessment

    public static let purpose =
        "Understand supplied Swift change evidence through one typed inference, then feed that typed understanding into a second inference that produces a bounded implementation and verification plan."

    @InferenceSite
    public static var understanding:
        Site<UnderstandSwiftChange>

    @InferenceSite
    public static var planning:
        Site<PlanSwiftChange>

    public init() {}

    public func run(
        _ input: Input,
        in context: ProgramContext
    ) async throws -> Output {
        let understanding = try await context.infer(
            Self.understanding,
            input: input
        )

        let plan = try await context.infer(
            Self.planning,
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
