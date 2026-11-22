import Agentic
import AgenticAssertions
import AgenticGit
import AgenticIO
import AgenticMath
import AgenticStandard
import AgenticTasks

/// Tool sets shared by the SwiftLang agents.
enum SwiftAgentTools {
    /// Interaction every agent may use; discovery comes from the runtime.
    static let standard: [ToolIdentifier] = [
        Standard.Tools.ClarifyWithUser.identifier,
    ]

    static let read: [ToolIdentifier] = [
        SystemIO.Tools.Read.identifier,

        SystemIO.Tools.Find.identifier,

        SystemIO.Tools.Search.identifier,
        SystemIO.Tools.ProveSearchResults.identifier,
    ]

    /// Structural and semantic Swift reading; nothing here mutates.
    static let swiftRead: [ToolIdentifier] = [
        SwiftLang.Tools.Parse.identifier,
        SwiftLang.Tools.ListSymbols.identifier,
        SwiftLang.Tools.ReadSymbol.identifier,
        SwiftLang.Tools.ReadStructure.identifier,
        SwiftLang.Tools.SearchArchitecture.identifier,
        SwiftLang.Tools.InspectArchitectureSymbol.identifier,
        SwiftLang.Tools.InspectArchitectureRelationships.identifier,
    ]

    /// Read-only Git tools; nothing that commits, pushes, or pulls.
    static let repositoryRead: [ToolIdentifier] = [
        Git.Tools.Diff.identifier,
        Git.Tools.RepositoryState.identifier,
    ]

    /// Deterministic checks over text and workspace files, for verification.
    static let assertionChecks: [ToolIdentifier] = [
        Assertions.Tools.Evaluate.identifier,
        Assertions.Tools.EvaluateSet.identifier,
        Assertions.Tools.InspectSet.identifier,
    ]

    static let guidelines: [ToolIdentifier] = [
        Standard.Tools.SearchGuidelines.identifier,
        Standard.Tools.GuidelineIndex.identifier,
        Standard.Tools.ReadGuideline.identifier,
        Standard.Tools.ReadGuidelineChapter.identifier,
    ]

    /// Domains available but hidden; reachable through capabilities_tool_search and capabilities_tool_search.
    static let discoverableDomains: [any Domain.Type] = [
        Math.self,
        Assertions.self,
    ]
}
