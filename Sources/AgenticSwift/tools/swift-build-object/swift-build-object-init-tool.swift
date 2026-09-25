import Agentic
import AgenticExecution
import Workspace
import Executable
import Primitives
import Schema
import Macros

public struct SwiftBuildObjectInitTool: Tool {
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Create minimal empty build-object/compiled files. Defaults to false.
        public let empty: Bool?

        /// Build object name. Defaults to workspace folder name.
        public let name: String?

        /// Executable object types. Defaults to [binary].
        public let types: [String]?

        /// Optional build-object details.
        public let details: String?

        /// Optional author. Defaults to current user.
        public let author: String?

        /// Optional update URL.
        public let update: String?

        /// Also create compiled.pkl when missing. Defaults to true.
        public let createCompiled: Bool?

        public init(
            empty: Bool? = nil,
            name: String? = nil,
            types: [String]? = nil,
            details: String? = nil,
            author: String? = nil,
            update: String? = nil,
            createCompiled: Bool? = nil
        ) {
            self.empty = empty
            self.name = name
            self.types = types
            self.details = details
            self.author = author
            self.update = update
            self.createCompiled = createCompiled
        }
    }

    @JSONSchema
    public struct Output: Sendable, Codable, Hashable {
        public let configuration: String
        public let compiled: String
        public let createdConfiguration: Bool
        public let createdCompiled: Bool

        public init(configuration: String, compiled: String, createdConfiguration: Bool, createdCompiled: Bool) {
            self.configuration = configuration
            self.compiled = compiled
            self.createdConfiguration = createdConfiguration
            self.createdCompiled = createdCompiled
        }
    }

public static let identifier: ToolIdentifier = "swift_build_object_init"
    public static let description =
        "Initialize build-object.pkl and optionally compiled.pkl through Executable.BuildObjectLifecycle."
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
