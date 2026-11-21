import Agentic
import Workspace
import Executable
import Primitives
import Schema
import Macros
import Version

public extension SwiftLang.Tools {
    @DomainMember(SwiftLang.self)
    struct IncrementVersion: Tool {
        @JSONSchema
        public struct Input:
            Sendable,
            Codable
        {
            /// Release version component to increment.
            public let level: ObjectVersionLevel

            public init(
                level: ObjectVersionLevel
            ) {
                self.level = level
            }
        }

        @JSONSchema
        public struct Output: Sendable, Codable, Hashable {
            /// The previous release tag; nil for the first release.
            public let before: String?
            /// The tag created on HEAD and pushed.
            public let after: String
            public let level: String

            public init(before: String?, after: String, level: String) {
                self.before = before
                self.after = after
                self.level = level
            }
        }

    public static let identifier: ToolIdentifier = SwiftLang.definition.toolIdentifier("increment_version")
        public static let description =
            "Release the next version: tag HEAD with it and push the tag. Refuses a dirty or unpushed HEAD."
        public static let risk: ActionRisk = .privileged

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
