import AgenticInference

public struct UnderstandBusinessConversation:
    AgentInference,
    Sendable
{
    public typealias Input = BusinessReplyRequest
    public typealias Output = BusinessConversationUnderstanding

    public static let definition = AgentInferenceDefinition(
        identifier: "business.understand_conversation",
        purpose: "Understand a supplied business conversation without inventing facts. Identify participant objectives, explicit requests, existing commitments, unresolved issues, communication risks, and at most one operator clarification when human judgment would materially improve the reply."
    )

    public init() {}
}
