import Agentic
import Workspace
import Executable
import Primitives
import Schema
import Version
import Macros


public extension SwiftLang.Tools {
    @DomainMember(SwiftLang.self)
    struct Version: Tool {
        @JSONSchema
        public struct Input:
            Codable,
            Sendable
        {
            public init() {}
        }

        @JSONSchema
        public struct Deployed:
            Sendable,
            Codable,
            Hashable
        {
            public let product: String
            /// Release the deployed binary was built from; nil when never deployed or untagged.
            public let version: String?
            public let commit: String?
            public let dirty: Bool?

            public init(product: String, version: String?, commit: String?, dirty: Bool?) {
                self.product = product
                self.version = version
                self.commit = commit
                self.dirty = dirty
            }
        }

        @JSONSchema
        public struct Output:
            Sendable,
            Codable,
            Hashable
        {
            /// Newest release tag reachable from HEAD; nil before the first release.
            public let release: String?
            public let commit: String?
            public let dirty: Bool?
            public let deployed: [Deployed]
            /// Deployed products built before the release (or never deployed).
            public let outdated: [String]
            public let ahead: Int?
            public let behind: Int?

            public init(
                release: String?,
                commit: String?,
                dirty: Bool?,
                deployed: [Deployed],
                outdated: [String],
                ahead: Int?,
                behind: Int?
            ) {
                self.release = release
                self.commit = commit
                self.dirty = dirty
                self.deployed = deployed
                self.outdated = outdated
                self.ahead = ahead
                self.behind = behind
            }
        }

    public static let identifier: ToolIdentifier = SwiftLang.definition.toolIdentifier("version")
        public static let description =
            "Inspect a package.frame project's release (git tag), HEAD, and what each deployed product was built from."
        public static let risk: ActionRisk = .observe

        public static let definition = ToolDefinition(
            identifier: identifier,
            purpose: description,
            risk: risk
        )
        public var identifier: ToolIdentifier {
            Self.identifier
        }

        public var description: String {
            Self.description
        }

        public var risk: ActionRisk {
            Self.risk
        }

        public init() {}


    }
}
