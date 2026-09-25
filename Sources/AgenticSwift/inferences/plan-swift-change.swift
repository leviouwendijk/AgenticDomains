import Agentic

@Inference
public struct PlanSwiftChange {
    public typealias Input = SwiftChangePlanningInput
    public typealias Output = SwiftChangePlan

    public static let purpose =
        "Plan a bounded Swift change from an already typed semantic understanding, preserving constraints and producing explicit verification and caveats."

    public init() {}
}
