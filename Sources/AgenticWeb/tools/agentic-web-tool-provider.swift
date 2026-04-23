import Agentic

public struct AgenticWebToolProvider: AgentToolProvider {
    public let provider: any WebSearchProvider
    public let policy: WebAccessPolicy
    public let sessionStore: WebSearchSessionStore

    public init(
        provider: any WebSearchProvider = UnavailableWebSearchProvider(),
        policy: WebAccessPolicy = .default,
        sessionStore: WebSearchSessionStore = .init()
    ) {
        self.provider = provider
        self.policy = policy
        self.sessionStore = sessionStore
    }

    public func registerTools(
        into registry: inout ToolRegistry
    ) throws {
        try registry.register(
            AgenticWebToolSet(
                provider: provider,
                policy: policy,
                sessionStore: sessionStore
            )
        )
    }
}
