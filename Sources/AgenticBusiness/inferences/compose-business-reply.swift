import AgenticInference

public struct ComposeBusinessReply:
    AgentInference,
    Sendable
{
    public typealias Input = BusinessReplyCompositionInput
    public typealias Output = BusinessReplyDraft

    public static let definition = AgentInferenceDefinition(
        identifier: "business.compose_reply",
        purpose: "Prepare structured reply assistance from the supplied conversation, typed understanding, constraints, and optional operator guidance. Return what must and should be included, explicit caveats, and multiple candidate replies without inventing commitments or sending anything."
    )

    public init() {}
}
