import Agentic

public extension Business.Inferences {
    @Inference
    struct UnderstandConversation {
        public typealias Input = BusinessReplyRequest
        public typealias Output = BusinessConversationUnderstanding

        public static let purpose =
            "Understand a supplied business conversation without inventing facts. Identify participant objectives, explicit requests, existing commitments, unresolved issues, communication risks, and at most one operator clarification when human judgment would materially improve the reply."

        public init() {}
    }
}
