import Agentic

public extension Business.Programs {
    @Program
    struct PrepareReply {
        public typealias Input = BusinessReplyRequest
        public typealias Output = BusinessReplyAssistance

        public static let purpose =
            "Understand a supplied business conversation, request optional operator guidance when a material communication decision remains unresolved, then prepare structured reply guidance and candidate responses for human review."

        @InferenceSite
        public static var understanding:
            Site<Business.Inferences.UnderstandConversation>

        @InferenceSite
        public static var composition:
            Site<Business.Inferences.ComposeReply>

        public init() {}

        public func run(
            _ input: Input,
            in context: ProgramContext
        ) async throws -> Output {
            let understanding = try await context.infer(
                Self.understanding,
                input: input
            )

            let operatorGuidance = try await askForOperatorGuidance(
                from: understanding,
                in: context
            )

            let draft = try await context.infer(
                Self.composition,
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
            in context: ProgramContext
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
}
