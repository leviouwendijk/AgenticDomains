import AgenticInference

public struct UnderstandSwiftChange:
    AgentInference,
    Sendable
{
    public typealias Input = SwiftChangeContext
    public typealias Output = SwiftChangeUnderstanding

    public static let definition = AgentInferenceDefinition(
        identifier: "swift.understand_change",
        purpose: "Understand the semantic impact of supplied Swift change evidence, including affected areas, risks, and unresolved uncertainty."
    )

    public init() {}
}
