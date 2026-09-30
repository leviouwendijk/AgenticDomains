import Agentic

private struct BusinessMessageTriageState: Encodable, Sendable {
    let message: BusinessConversationMessage
    let context: BusinessConversation?
}

public extension Business.Inferences {
    @Inference(.decision)
    struct TriageMessage {
        public typealias Input = BusinessMessageTriageInput
        public typealias Output = BusinessMessageTriage

        public static let purpose = """
            Assess an incoming business message for whether it matters, which supplied business category owns it, how urgently it requires attention, and how consequential the underlying issue is.
            """

        public static func decision(for input: Input) throws -> Decision.Specification<Output> {
            let relevance = try Decision.binary(
                id: "relevance",
                instructions: "Does this message materially require attention, action, routing, response, or awareness from the business?",
                positive: "The message has meaningful business relevance and deserves attention, action, routing, response, or awareness.",
                negative: "The message has no meaningful business relevance and does not require attention, action, routing, response, or awareness."
            )

            let category = try Decision.choice(
                id: "category",
                instructions: "Which supplied business category best owns or describes this message?",
                options: try input.categories.map { category in
                    try Decision.Option(
                        id: category.id,
                        value: category,
                        description: Decision.Content(category.description)
                    )
                }
            )

            let urgency = try Decision.score(
                id: "urgency",
                instructions: "How time-sensitive is this message? Judge how soon the business should pay attention or act, independently of how consequential the issue is.",
                scale: try urgencyScale()
            )

            let impact = try Decision.score(
                id: "impact",
                instructions: "How consequential is this message or underlying issue for the client or business if it is mishandled, ignored, or left unresolved? Judge consequence independently of time sensitivity.",
                scale: try impactScale()
            )

            let query = try Decision.zip(
                Decision.zip(relevance, category),
                Decision.zip(urgency, impact)
            )
            .map { combined in
                BusinessMessageTriage(
                    relevance: combined.0.0,
                    category: combined.0.1,
                    urgency: combined.1.0,
                    impact: combined.1.1
                )
            }

            return try Decision.Specification(
                state: BusinessMessageTriageState(
                    message: input.message,
                    context: input.context
                ),
                query: query
            )
        }

        private static func urgencyScale() throws -> Decision.Scale<BusinessUrgency> {
            try Decision.Scale(
                id: "business_message_urgency",
                levels: [
                    try Decision.Option(
                        id: "low",
                        value: .low,
                        description: "No near-term action is needed; ordinary delay is unlikely to materially affect the outcome."
                    ),
                    try Decision.Option(
                        id: "routine",
                        value: .routine,
                        description: "Should be handled in the normal course of business without special acceleration."
                    ),
                    try Decision.Option(
                        id: "high",
                        value: .high,
                        description: "Prompt attention is warranted because delay could inconvenience the client, complicate resolution, or worsen the situation."
                    ),
                    try Decision.Option(
                        id: "immediate",
                        value: .immediate,
                        description: "Time-critical; action or attention should occur as soon as practical because delay materially threatens the outcome."
                    )
                ]
            )
        }

        private static func impactScale() throws -> Decision.Scale<BusinessImpact> {
            try Decision.Scale(
                id: "business_message_impact",
                levels: [
                    try Decision.Option(
                        id: "minor",
                        value: .minor,
                        description: "Little consequence for the client or business if handling is imperfect or delayed."
                    ),
                    try Decision.Option(
                        id: "moderate",
                        value: .moderate,
                        description: "Meaningful but contained consequences that deserve normal professional attention."
                    ),
                    try Decision.Option(
                        id: "major",
                        value: .major,
                        description: "Significant consequences for the client relationship, service outcome, operations, finances, or reputation."
                    ),
                    try Decision.Option(
                        id: "critical",
                        value: .critical,
                        description: "Potentially severe consequences requiring exceptional care because mishandling could cause substantial harm or loss."
                    )
                ]
            )
        }
    }
}
