import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Primitives
import Schema
import SchemaMacros
import Version

@JSONSchema
public struct SwiftIncrementVersionToolInput:
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

public struct SwiftIncrementVersionTool: TypedAgentTool {
    public typealias Input = SwiftIncrementVersionToolInput
    public static let identifier: AgentToolIdentifier = "swift_increment_version"
    public static let description =
        "Increment the build-object release version through Executable."
    public static let risk: ActionRisk = .boundedmutate
    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            SwiftIncrementVersionToolInput.self,
            from: input
        )
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: workspace.rootURL.path,
            targetPaths: [
                "build-object.pkl",
            ],
            summary: "Increment Swift release \(decoded.level.rawValue) version.",
            estimatedWriteCount: 1,
            sideEffects: [
                "Updates the release version in build-object.pkl.",
            ],
            policyChecks: [
                "workspace_required",
                "typed_executable_version_increment",
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftIncrementVersionToolInput.self,
            from: input
        )
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            workspace,
            toolName: name
        )
        let result = try ExecutableVersion.incrementRelease(
            at: workspace.rootURL,
            level: decoded.level
        )

        return .object([
            "before": .string(
                result.before.string(
                    prefixStyle: .short,
                    prefixSpace: false
                )
            ),
            "after": .string(
                result.after.string(
                    prefixStyle: .short,
                    prefixSpace: false
                )
            ),
            "level": .string(result.level.rawValue),
            "path": .string(result.configurationURL.path),
        ])
    }
}
