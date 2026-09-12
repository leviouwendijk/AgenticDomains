import Schema
import SchemaMacros

@JSONSchema
public struct DayPriority:
    Sendable,
    Codable,
    Hashable
{
    public let title: String
    public let rationale: String

    public init(
        title: String,
        rationale: String
    ) {
        self.title = title
        self.rationale = rationale
    }
}

@JSONSchema
public struct DayWarning:
    Sendable,
    Codable,
    Hashable
{
    public let summary: String
    public let rationale: String

    public init(
        summary: String,
        rationale: String
    ) {
        self.summary = summary
        self.rationale = rationale
    }
}

@JSONSchema
public struct DayRecommendation:
    Sendable,
    Codable,
    Hashable
{
    public let action: String
    public let rationale: String

    public init(
        action: String,
        rationale: String
    ) {
        self.action = action
        self.rationale = rationale
    }
}

@JSONSchema
public struct DayInformationGap:
    Sendable,
    Codable,
    Hashable
{
    public let subject: String
    public let reason: String

    public init(
        subject: String,
        reason: String
    ) {
        self.subject = subject
        self.reason = reason
    }
}
