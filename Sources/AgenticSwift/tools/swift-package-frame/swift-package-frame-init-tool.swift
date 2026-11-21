import Agentic
import Workspace
import Executable
import Primitives
import Schema
import Macros

public extension SwiftLang.Tools {
    @DomainMember(SwiftLang.self)
    struct PackageFrameInit: Tool {
        @JSONSchema
        public struct Input:
            Sendable,
            Codable,
            Hashable
        {
            public init() {}
        }

        @JSONSchema
        public struct Output: Sendable, Codable, Hashable {
            /// package.frame, when it was created; nil when it already existed.
            public let package: String?
            /// Tests/package.frame, when it was created; nil when it existed or there is no Tests/ package.
            public let tests: String?

            public init(package: String?, tests: String?) {
                self.package = package
                self.tests = tests
            }
        }

    public static let identifier: ToolIdentifier = SwiftLang.definition.toolIdentifier("package_frame_init")
        public static let description =
            "Write package.frame (and Tests/package.frame when Tests/ holds a Package.swift) with empty descriptions; existing files are kept."
        public static let risk: ActionRisk = .boundedmutate

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
