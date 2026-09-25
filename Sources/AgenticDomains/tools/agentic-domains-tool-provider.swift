import AgenticAppleServices
import AgenticExecution
import AgenticGit
import AgenticSwift
import AgenticWeb

public struct AgenticDomainsToolProvider:
    AgentToolProvider
{
    public let swiftLang: AgenticSwiftToolProvider
    public let git: AgenticGitToolProvider
    public let web: WebToolProvider
    public let appleServices: AppleServicesToolProvider

    public init(
        swiftLang: AgenticSwiftToolProvider = .init(),
        git: AgenticGitToolProvider = .init(),
        web: WebToolProvider = .init(),
        appleServices: AppleServicesToolProvider = .init()
    ) {
        self.swiftLang = swiftLang
        self.git = git
        self.web = web
        self.appleServices = appleServices
    }

    public init(
        webSearchProvider: any WebSearchProvider,
        webAccessPolicy: WebAccessPolicy = .default,
        webSearchSessionStore: WebSearchSessionStore = .init()
    ) {
        self.init(
            web: WebToolProvider(
                provider: webSearchProvider,
                policy: webAccessPolicy,
                sessionStore: webSearchSessionStore
            )
        )
    }

    public func registerTools(
        into registry: inout ToolRegistry
    ) throws {
        try swiftLang.registerTools(
            into: &registry
        )

        try git.registerTools(
            into: &registry
        )

        try web.registerTools(
            into: &registry
        )

        try appleServices.registerTools(
            into: &registry
        )
    }
}
