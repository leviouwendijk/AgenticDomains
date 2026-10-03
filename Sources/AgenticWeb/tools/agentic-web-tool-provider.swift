import Agentic

public struct WebToolProvider: AgentToolProvider {
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
            Web.Tools.Search(
                provider: provider,
                policy: policy,
                sessionStore: sessionStore
            )
        )

        try registry.register(
            Web.Tools.OpenResult(
                provider: provider,
                policy: policy,
                sessionStore: sessionStore
            )
        )
    }
}
