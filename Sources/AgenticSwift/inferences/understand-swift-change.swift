import Agentic

public extension SwiftLang.Inferences {
    @Inference
    struct UnderstandChange {
        public typealias Input = SwiftChangeContext
        public typealias Output = SwiftChangeUnderstanding

        public static let purpose =
            "Understand the semantic impact of supplied Swift change evidence, including affected areas, risks, and unresolved uncertainty."

        public init() {}
    }
}
