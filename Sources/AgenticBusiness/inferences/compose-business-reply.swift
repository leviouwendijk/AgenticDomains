import Agentic

public extension Business.Inferences {
    @Inference
    struct ComposeReply {
        public typealias Input = BusinessReplyCompositionInput
        public typealias Output = BusinessReplyDraft

        public static let purpose =
            "Prepare structured reply assistance from the supplied conversation, typed understanding, constraints, and optional operator guidance. Return what must and should be included, explicit caveats, and multiple candidate replies without inventing commitments or sending anything."

        public init() {}
    }
}
