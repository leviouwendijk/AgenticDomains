import Agentic
import Macros
import Schema

@JSONSchema
public struct BusinessMessageCategory: HashableProduct {
    public let id: String
    public let description: String

    public init(
        id: String,
        description: String
    ) {
        self.id = id
        self.description = description
    }
}

public enum BusinessUrgency: String, HashableProduct, CaseIterable {
    case low
    case routine
    case high
    case immediate

    public static var jsonschema: JSONSchema {
        String.jsonschema
    }
}

public enum BusinessImpact: String, HashableProduct, CaseIterable {
    case minor
    case moderate
    case major
    case critical

    public static var jsonschema: JSONSchema {
        String.jsonschema
    }
}

@JSONSchema
public struct BusinessMessageTriageInput: HashableSource {
    public let message: BusinessConversationMessage
    public let context: BusinessConversation?
    public let categories: [BusinessMessageCategory]

    public init(
        message: BusinessConversationMessage,
        context: BusinessConversation? = nil,
        categories: [BusinessMessageCategory]
    ) {
        self.message = message
        self.context = context
        self.categories = categories
    }
}

@JSONSchema
public struct BusinessMessageTriage: HashableResult {
    public let relevance: Decision.Probability
    public let category: Decision.Choice<BusinessMessageCategory>
    public let urgency: Decision.Score<BusinessUrgency>
    public let impact: Decision.Score<BusinessImpact>

    public init(
        relevance: Decision.Probability,
        category: Decision.Choice<BusinessMessageCategory>,
        urgency: Decision.Score<BusinessUrgency>,
        impact: Decision.Score<BusinessImpact>
    ) {
        self.relevance = relevance
        self.category = category
        self.urgency = urgency
        self.impact = impact
    }
}
