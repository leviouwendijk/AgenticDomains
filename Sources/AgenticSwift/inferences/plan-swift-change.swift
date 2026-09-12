import AgenticInference

public struct PlanSwiftChange:
    AgentInference,
    Sendable
{
    public typealias Input = SwiftChangePlanningInput
    public typealias Output = SwiftChangePlan

    public static let definition = AgentInferenceDefinition(
        identifier: "swift.plan_changes",
        purpose: "Plan a bounded Swift change from an already typed semantic understanding, preserving constraints and producing explicit verification and caveats."
    )

    public init() {}
}
