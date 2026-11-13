import Agentic

public extension SwiftLang.Inferences {
    @Inference
    struct PlanChange {
        public typealias Input = SwiftChangePlanningInput
        public typealias Output = SwiftChangePlan

        public static let purpose =
            "Plan a bounded Swift change from an already typed semantic understanding, preserving constraints and producing explicit verification and caveats."

        public init() {}
    }
}
