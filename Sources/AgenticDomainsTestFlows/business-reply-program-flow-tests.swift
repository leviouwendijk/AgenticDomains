import Agentic
import AgenticBusiness
import AgenticInference
import AgenticPrograms
import Foundation
import TestFlows

private enum BusinessReplyProgramFixtureError: Error {
    case unexpectedInference(String)
    case unexpectedInferenceSite(String)
    case missingOperatorGuidance
    case nonOptionalClarification
}

private struct BusinessReplyInferenceFixture:
    AgentInferenceInvoking
{
    func infer<Inference: AgentInference>(
        _ inference: Inference.Type,
        at site: AgentInferenceSiteIdentifier,
        input: Inference.Input
    ) async throws -> Inference.Output {
        if inference.definition.identifier
            == UnderstandBusinessConversation.definition.identifier
        {
            guard site == PrepareBusinessReplyProgram.understandingSite else {
                throw BusinessReplyProgramFixtureError.unexpectedInferenceSite(
                    site.rawValue
                )
            }

            let output = BusinessConversationUnderstanding(
                summary: "The participant wants to reschedule and asks whether earlier guidance still applies.",
                participantObjectives: [
                    "Reschedule the appointment.",
                    "Know what to do until the new appointment.",
                ],
                explicitRequests: [
                    "Confirm which proposed day can be offered.",
                    "Clarify whether earlier guidance remains applicable.",
                ],
                commitments: [
                    "The organization said it would check availability before confirming.",
                ],
                unresolvedIssues: [
                    "No scheduling option has yet been selected by the operator.",
                ],
                communicationRisks: [
                    "Do not imply that an unconfirmed appointment is booked.",
                ],
                clarification: BusinessReplyClarification(
                    prompt: "Which scheduling option should the reply offer?",
                    reason: "The conversation contains candidate days, but choosing what the organization can offer requires operator judgment."
                )
            )
            let encodedOutput = try JSONEncoder().encode(output)

            return try JSONDecoder().decode(
                Inference.Output.self,
                from: encodedOutput
            )
        }

        if inference.definition.identifier
            == ComposeBusinessReply.definition.identifier
        {
            guard site == PrepareBusinessReplyProgram.compositionSite else {
                throw BusinessReplyProgramFixtureError.unexpectedInferenceSite(
                    site.rawValue
                )
            }

            let encodedInput = try JSONEncoder().encode(input)
            let typedInput = try JSONDecoder().decode(
                BusinessReplyCompositionInput.self,
                from: encodedInput
            )

            guard typedInput.operatorGuidance
                == "Offer both Tuesday and Thursday as options; do not describe either as confirmed."
            else {
                throw BusinessReplyProgramFixtureError.missingOperatorGuidance
            }

            let output = BusinessReplyDraft(
                mustInclude: [
                    "Acknowledge the rescheduling request.",
                    "State the scheduling option without presenting it as confirmed.",
                    "Answer whether the earlier guidance still applies.",
                ],
                shouldInclude: [
                    "Keep the reply concise and easy to act on.",
                ],
                caveats: typedInput.understanding.communicationRisks,
                candidates: [
                    BusinessReplyCandidate(
                        label: "concise",
                        message: "Tuesday or Thursday can both be offered as options. We still need to confirm the final appointment, and the earlier guidance remains the working approach until then.",
                        rationale: typedInput.operatorGuidance ?? ""
                    ),
                    BusinessReplyCandidate(
                        label: "warmer",
                        message: "Thanks for checking in. We can offer Tuesday or Thursday as options and will confirm the final appointment once one is selected. Until then, you can continue with the earlier guidance.",
                        rationale: "Preserves the same commitments with a warmer acknowledgement."
                    ),
                ]
            )
            let encodedOutput = try JSONEncoder().encode(output)

            return try JSONDecoder().decode(
                Inference.Output.self,
                from: encodedOutput
            )
        }

        throw BusinessReplyProgramFixtureError.unexpectedInference(
            inference.definition.identifier.rawValue
        )
    }
}

private actor BusinessReplyUserInputFixture:
    AgentProgramUserInputInvoking
{
    private var requestCount = 0

    func ask(
        _ request: UserInputRequest
    ) async throws -> UserInputResponse {
        guard request.requirement == .optional else {
            throw BusinessReplyProgramFixtureError.nonOptionalClarification
        }

        requestCount += 1

        return try UserInputResponse(
            answer: .text(
                "Offer both Tuesday and Thursday as options; do not describe either as confirmed."
            ),
            for: request
        )
    }

    func count() -> Int {
        requestCount
    }
}

extension AgenticDomainsFlowTesting {
    static func runBusinessReplyProgram() async throws
        -> [TestFlowDiagnostic]
    {
        let userInput = BusinessReplyUserInputFixture()
        var registry = ProgramRegistry()

        try AgenticBusinessProgramSet().register(
            into: &registry
        )

        try Expect.equal(
            registry.count,
            1,
            "AgenticBusiness Program set registers the reply-assistance Program"
        )
        try Expect.equal(
            registry.descriptors.first?.identifier.rawValue ?? "",
            "business.prepare_reply",
            "AgenticBusiness exposes the reply-assistance Program through ProgramRegistry"
        )

        let input = BusinessReplyRequest(
            conversation: BusinessConversation(
                messages: [
                    BusinessConversationMessage(
                        speaker: "participant",
                        content: "Could we move the appointment? Tuesday or Thursday may work. Does the earlier recommendation still apply until then?"
                    ),
                    BusinessConversationMessage(
                        speaker: "organization",
                        content: "We can check availability and confirm."
                    ),
                ]
            ),
            objective: "Answer the participant clearly while preserving the distinction between an option and a confirmed commitment.",
            context: [
                "The operator has not yet selected which scheduling option to offer.",
            ],
            constraints: [
                "Do not invent availability.",
                "Do not imply that a booking is confirmed.",
            ]
        )

        let output = try await PrepareBusinessReplyProgram().run(
            input,
            in: AgentProgramContext(
                inference: BusinessReplyInferenceFixture(),
                userInput: userInput
            )
        )
        let questionCount = await userInput.count()

        try Expect.equal(
            questionCount,
            1,
            "PrepareBusinessReplyProgram directly asks one optional operator clarification when understanding surfaces one"
        )
        try Expect.equal(
            output.operatorGuidance ?? "",
            "Offer both Tuesday and Thursday as options; do not describe either as confirmed.",
            "Program output preserves operator guidance"
        )
        try Expect.equal(
            output.understanding.explicitRequests.count,
            2,
            "Program output preserves the typed conversation understanding"
        )
        try Expect.equal(
            output.draft.candidates.count,
            2,
            "Program output carries multiple reply candidates for human review"
        )
        try Expect.equal(
            output.draft.caveats.first ?? "",
            "Do not imply that an unconfirmed appointment is booked.",
            "Composition receives typed understanding and preserves communication caveats"
        )

        return [
            .field(
                "program",
                PrepareBusinessReplyProgram.descriptor.identifier.rawValue
            ),
            .field(
                "operator_questions",
                "\(questionCount)"
            ),
            .field(
                "candidates",
                "\(output.draft.candidates.count)"
            ),
        ]
    }
}
