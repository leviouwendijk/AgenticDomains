import Agentic
import AgenticGit
import AgenticSwift
import AgenticWeb

public struct AgenticDomainsToolSet:
    AgentToolSet
{
    public let web: AgenticWebToolSet

    public init(
        web: AgenticWebToolSet = .init()
    ) {
        self.web = web
    }

    public init(
        webSearchProvider: any WebSearchProvider,
        webAccessPolicy: WebAccessPolicy = .default,
        webSearchSessionStore: WebSearchSessionStore = .init()
    ) {
        self.init(
            web: .init(
                provider: webSearchProvider,
                policy: webAccessPolicy,
                sessionStore: webSearchSessionStore
            )
        )
    }

    public func register(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register(
            AgenticSwiftToolSet()
        )

        try registry.register(
            AgenticGitToolSet()
        )

        try registry.register(
            web
        )
    }
}
