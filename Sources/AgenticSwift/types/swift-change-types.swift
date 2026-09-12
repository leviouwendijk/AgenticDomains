import Schema
import SchemaMacros

@JSONSchema
public struct SwiftChangeContext:
    Sendable,
    Codable,
    Hashable
{
    public let objective: String
    public let evidence: [String]
    public let constraints: [String]

    public init(
        objective: String,
        evidence: [String],
        constraints: [String] = []
    ) {
        self.objective = objective
        self.evidence = evidence
        self.constraints = constraints
    }
}

@JSONSchema
public struct SwiftChangeUnderstanding:
    Sendable,
    Codable,
    Hashable
{
    public let summary: String
    public let affectedAreas: [String]
    public let risks: [String]
    public let uncertainties: [String]

    public init(
        summary: String,
        affectedAreas: [String],
        risks: [String],
        uncertainties: [String]
    ) {
        self.summary = summary
        self.affectedAreas = affectedAreas
        self.risks = risks
        self.uncertainties = uncertainties
    }
}

@JSONSchema
public struct SwiftChangePlanningInput:
    Sendable,
    Codable,
    Hashable
{
    public let objective: String
    public let constraints: [String]
    public let understanding: SwiftChangeUnderstanding

    public init(
        objective: String,
        constraints: [String],
        understanding: SwiftChangeUnderstanding
    ) {
        self.objective = objective
        self.constraints = constraints
        self.understanding = understanding
    }
}

@JSONSchema
public struct SwiftChangeStep:
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
public struct SwiftChangePlan:
    Sendable,
    Codable,
    Hashable
{
    public let steps: [SwiftChangeStep]
    public let verification: [String]
    public let caveats: [String]

    public init(
        steps: [SwiftChangeStep],
        verification: [String],
        caveats: [String]
    ) {
        self.steps = steps
        self.verification = verification
        self.caveats = caveats
    }
}

public struct SwiftChangeAssessment:
    Sendable,
    Codable,
    Hashable
{
    public let understanding: SwiftChangeUnderstanding
    public let plan: SwiftChangePlan

    public init(
        understanding: SwiftChangeUnderstanding,
        plan: SwiftChangePlan
    ) {
        self.understanding = understanding
        self.plan = plan
    }
}
