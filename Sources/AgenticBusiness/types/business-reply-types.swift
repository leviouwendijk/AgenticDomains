import Schema
import Macros

@JSONSchema
public struct BusinessConversationMessage:
    Sendable,
    Codable,
    Hashable
{
    public let speaker: String
    public let content: String

    public init(
        speaker: String,
        content: String
    ) {
        self.speaker = speaker
        self.content = content
    }
}

@JSONSchema
public struct BusinessConversation:
    Sendable,
    Codable,
    Hashable
{
    public let messages: [BusinessConversationMessage]

    public init(
        messages: [BusinessConversationMessage]
    ) {
        self.messages = messages
    }
}

@JSONSchema
public struct BusinessReplyRequest:
    Sendable,
    Codable,
    Hashable
{
    public let conversation: BusinessConversation
    public let objective: String
    public let context: [String]
    public let constraints: [String]

    public init(
        conversation: BusinessConversation,
        objective: String,
        context: [String] = [],
        constraints: [String] = []
    ) {
        self.conversation = conversation
        self.objective = objective
        self.context = context
        self.constraints = constraints
    }
}

@JSONSchema
public struct BusinessReplyClarification:
    Sendable,
    Codable,
    Hashable
{
    public let prompt: String
    public let reason: String

    public init(
        prompt: String,
        reason: String
    ) {
        self.prompt = prompt
        self.reason = reason
    }
}

@JSONSchema
public struct BusinessConversationUnderstanding:
    Sendable,
    Codable,
    Hashable
{
    public let summary: String
    public let participantObjectives: [String]
    public let explicitRequests: [String]
    public let commitments: [String]
    public let unresolvedIssues: [String]
    public let communicationRisks: [String]
    public let clarification: BusinessReplyClarification?

    public init(
        summary: String,
        participantObjectives: [String],
        explicitRequests: [String],
        commitments: [String],
        unresolvedIssues: [String],
        communicationRisks: [String],
        clarification: BusinessReplyClarification? = nil
    ) {
        self.summary = summary
        self.participantObjectives = participantObjectives
        self.explicitRequests = explicitRequests
        self.commitments = commitments
        self.unresolvedIssues = unresolvedIssues
        self.communicationRisks = communicationRisks
        self.clarification = clarification
    }
}

@JSONSchema
public struct BusinessReplyCompositionInput:
    Sendable,
    Codable,
    Hashable
{
    public let request: BusinessReplyRequest
    public let understanding: BusinessConversationUnderstanding
    public let operatorGuidance: String?

    public init(
        request: BusinessReplyRequest,
        understanding: BusinessConversationUnderstanding,
        operatorGuidance: String?
    ) {
        self.request = request
        self.understanding = understanding
        self.operatorGuidance = operatorGuidance
    }
}

@JSONSchema
public struct BusinessReplyCandidate:
    Sendable,
    Codable,
    Hashable
{
    public let label: String
    public let message: String
    public let rationale: String

    public init(
        label: String,
        message: String,
        rationale: String
    ) {
        self.label = label
        self.message = message
        self.rationale = rationale
    }
}

@JSONSchema
public struct BusinessReplyDraft:
    Sendable,
    Codable,
    Hashable
{
    public let mustInclude: [String]
    public let shouldInclude: [String]
    public let caveats: [String]
    public let candidates: [BusinessReplyCandidate]

    public init(
        mustInclude: [String],
        shouldInclude: [String],
        caveats: [String],
        candidates: [BusinessReplyCandidate]
    ) {
        self.mustInclude = mustInclude
        self.shouldInclude = shouldInclude
        self.caveats = caveats
        self.candidates = candidates
    }
}

public struct BusinessReplyAssistance:
    Sendable,
    Codable,
    Hashable
{
    public let understanding: BusinessConversationUnderstanding
    public let operatorGuidance: String?
    public let draft: BusinessReplyDraft

    public init(
        understanding: BusinessConversationUnderstanding,
        operatorGuidance: String?,
        draft: BusinessReplyDraft
    ) {
        self.understanding = understanding
        self.operatorGuidance = operatorGuidance
        self.draft = draft
    }
}
