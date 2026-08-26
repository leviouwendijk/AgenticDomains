import Agentic
import Executable
import Foundation
import Primitives

public struct SwiftBuildToolInput:
    Sendable,
    Codable,
    Hashable
{
    public enum Configuration:
        String,
        Sendable,
        Codable,
        Hashable,
        CaseIterable
    {
        case debug
        case release
    }

    public let configuration:
        Configuration

    public init(
        configuration:
            Configuration = .debug
    ) {
        self.configuration =
            configuration
    }

    private enum CodingKeys:
        String,
        CodingKey
    {
        case configuration
    }

    public init(
        from decoder: Decoder
    ) throws {
        let container =
            try decoder.container(
                keyedBy:
                    CodingKeys.self
            )

        self.init(
            configuration:
                try container
                    .decodeIfPresent(
                        Configuration.self,
                        forKey:
                            .configuration
                    )
                    ?? .debug
        )
    }

    public static var schema:
        JSONValue
    {
        JSONSchema.object {
            JSONSchema.string(
                "configuration",
                description:
                    "Swift build configuration. Defaults to debug.",
                cases:
                    Configuration
                        .allCases
                        .map(\.rawValue)
            )
        }
    }
}

public struct SwiftBuildToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let configuration: String
    public let isSuccess: Bool
    public let exitCode: Int
    public let stdout: String
    public let stderr: String
    public let buildDirComponent: String

    public init(
        configuration: String,
        isSuccess: Bool,
        exitCode: Int,
        stdout: String,
        stderr: String,
        buildDirComponent: String
    ) {
        self.configuration =
            configuration
        self.isSuccess =
            isSuccess
        self.exitCode =
            exitCode
        self.stdout =
            stdout
        self.stderr =
            stderr
        self.buildDirComponent =
            buildDirComponent
    }
}

public struct SwiftBuildTool:
    StaticAgentTool
{
    public static let identifier:
        AgentToolIdentifier =
            "swift_build"

    public static let description =
        """
        Build the current SwiftPM workspace using Executable's governed captured build path. Agentic disables Executable built-version bookkeeping.
        """

    public static let risk:
        ActionRisk = .privileged

    public static var inputSchema:
        JSONValue?
    {
        SwiftBuildToolInput.schema
    }

    public init() {}

    public func preflight(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> ToolPreflight {
        let decoded =
            try JSONToolBridge.decode(
                SwiftBuildToolInput.self,
                from: input
            )

        let workspace =
            try AgenticSwiftToolSupport
                .requireWorkspace(
                    workspace,
                    toolName: name
                )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot:
                workspace.rootURL.path,
            targetPaths: [
                ".build/",
            ],
            summary:
                "Build the Swift package in \(decoded.configuration.rawValue) configuration.",
            commandPreview:
                "swift build -c \(decoded.configuration.rawValue)",
            estimatedWriteCount: 1,
            estimatedRuntimeSeconds: 300,
            sideEffects: [
                "Writes SwiftPM build artifacts under .build.",
                "SwiftPM may resolve or fetch package dependencies.",
                "Package or build-plugin code may execute with the current host permissions.",
                "Executable built-version snapshot bookkeeping is disabled for this invocation.",
            ],
            policyChecks: [
                "workspace_required",
                "typed_swift_build",
                "built_version_snapshot_disabled",
                "human_review_required",
            ],
            warnings: [
                "SwiftPM build execution is not confined by Agentic PathSandbox."
            ]
        )
    }

    public func call(
        input: JSONValue,
        workspace: AgentWorkspace?
    ) async throws -> JSONValue {
        let decoded =
            try JSONToolBridge.decode(
                SwiftBuildToolInput.self,
                from: input
            )

        let workspace =
            try AgenticSwiftToolSupport
                .requireWorkspace(
                    workspace,
                    toolName: name
                )

        let mode:
            Build.Config.Mode =
                switch decoded.configuration {
                case .debug:
                    .debug

                case .release:
                    .release
                }

        let config =
            Build.Config(
                mode: mode,
                updateBuiltOnSuccess:
                    false
            )

        do {
            let result =
                try await Build.captured(
                    at:
                        workspace.rootURL,
                    config:
                        config
                )

            return try JSONToolBridge.encode(
                SwiftBuildToolOutput(
                    configuration:
                        decoded
                            .configuration
                            .rawValue,
                    isSuccess:
                        result.exitCode == 0,
                    exitCode:
                        Int(
                            result.exitCode
                        ),
                    stdout:
                        String(
                            decoding:
                                result.stdout,
                            as:
                                UTF8.self
                        ),
                    stderr:
                        String(
                            decoding:
                                result.stderr,
                            as:
                                UTF8.self
                        ),
                    buildDirComponent:
                        result
                            .buildDirComponent
                )
            )
        } catch BuildError.swiftFailed(
            let exitCode,
            let stdout,
            let stderr
        ) {
            return try JSONToolBridge.encode(
                SwiftBuildToolOutput(
                    configuration:
                        decoded
                            .configuration
                            .rawValue,
                    isSuccess:
                        false,
                    exitCode:
                        exitCode,
                    stdout:
                        stdout,
                    stderr:
                        stderr,
                    buildDirComponent:
                        decoded
                            .configuration
                            .rawValue
                )
            )
        }
    }

    public func receipt(
        input _: JSONValue,
        output: JSONValue,
        workspace _: AgentWorkspace?
    ) -> AgentToolReceipt? {
        guard let result =
            try? JSONToolBridge.decode(
                SwiftBuildToolOutput.self,
                from: output
            )
        else {
            return nil
        }

        var items: [AgentToolReceipt.Item] = [
            .init(
                label: "configuration",
                value: result.configuration
            ),
            .init(
                label: "exit",
                value: "\(result.exitCode)"
            ),
            .init(
                label: "build dir",
                value: result.buildDirComponent
            ),
        ]

        if !result.stdout.isEmpty {
            items.append(
                .init(
                    label: "stdout",
                    value: result.stdout
                )
            )
        }

        if !result.stderr.isEmpty {
            items.append(
                .init(
                    label: "stderr",
                    value: result.stderr
                )
            )
        }

        return .init(
            status:
                result.isSuccess
                    ? "passed"
                    : "failed",
            summary:
                result.isSuccess
                    ? "Swift build completed successfully."
                    : "Swift build completed with a nonzero exit status.",
            items: items
        )
    }
}
