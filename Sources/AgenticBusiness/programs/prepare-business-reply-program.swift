import Agentic
import AgenticPrograms

public struct PrepareBusinessReplyProgram:
    AgentProgram,
    Sendable
{
    public typealias Input = BusinessReplyRequest
    public typealias Output = BusinessReplyAssistance

    public static let understandingSite: AgentInferenceSiteIdentifier =
        "understand_conversation"

    public static let compositionSite: AgentInferenceSiteIdentifier =
        "compose_reply"

    public static let descriptor = AgentProgramDescriptor(
        identifier: "business.prepare_reply",
        title: "Prepare Business Reply",
        summary: "Understand a supplied business conversation, request optional operator guidance when a material communication decision remains unresolved, then prepare structured reply guidance and candidate responses for human review.",
        tags: [
            "business",
            "communication",
            "reply",
            "inference",
            "human_input",
        ]
    )

    public init() {}

    public func run(
        _ input: Input,
        in context: AgentProgramContext
    ) async throws -> Output {
        let understanding = try await context.infer(
            UnderstandBusinessConversation.self,
            at: Self.understandingSite,
            input: input
        )

        let operatorGuidance = try await askForOperatorGuidance(
            from: understanding,
            in: context
        )

        let draft = try await context.infer(
            ComposeBusinessReply.self,
            at: Self.compositionSite,
            input: BusinessReplyCompositionInput(
                request: input,
                understanding: understanding,
                operatorGuidance: operatorGuidance
            )
        )

        return BusinessReplyAssistance(
            understanding: understanding,
            operatorGuidance: operatorGuidance,
            draft: draft
        )
    }

    private func askForOperatorGuidance(
        from understanding: BusinessConversationUnderstanding,
        in context: AgentProgramContext
    ) async throws -> String? {
        guard let clarification = understanding.clarification else {
            return nil
        }

        let response = try await context.ask(
            UserInputRequest(
                prompt: clarification.prompt,
                reason: clarification.reason,
                requirement: .optional,
                metadata: [
                    "domain": "business",
                    "operation": "prepare_reply",
                ]
            )
        )

        guard case .answered(.text(let answer)) = response.outcome else {
            return nil
        }

        return answer
    }
}
