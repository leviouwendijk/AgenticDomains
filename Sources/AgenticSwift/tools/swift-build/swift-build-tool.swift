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
        Configuration?

    public init(
        configuration:
            Configuration? = nil
    ) {
        self.configuration =
            configuration
    }

    public static var schema:
        JSONValue
    {
        JSONSchema.object {
            JSONSchema.string(
                "configuration",
                description:
                    "Optional explicit Swift build configuration. Omit to use the project default, including enabled build-object.pkl compile instructions.",
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
        Build the current SwiftPM workspace through Executable's typed Build.Request -> Build.resolve -> Build.execute workflow. Omit configuration to use normal sbm project defaults, including enabled build-object.pkl interception and deployment behavior. Explicit debug/release overrides do not deploy. Agentic disables built-version bookkeeping.
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

        let request = try buildRequest(
            decoded,
            workspace: workspace
        )

        var targetPaths = [
            ".build/",
        ]

        var sideEffects = [
            "Writes SwiftPM build artifacts under .build.",
            "SwiftPM may resolve or fetch package dependencies.",
            "Package or build-plugin code may execute with the current host permissions.",
            "Executable built-version snapshot bookkeeping is disabled for this invocation.",
        ]

        var policyChecks = [
            "workspace_required",
            "typed_swift_build",
            "built_version_snapshot_disabled",
            "typed_build_request_resolution_execution",
            "human_review_required",
        ]

        if request.deploy {
            targetPaths.append(
                request.destination.path
            )
            sideEffects.append(
                "Deploys selected executable products according to the resolved Executable build request."
            )
            policyChecks.append(
                "project_build_deployment_enabled"
            )
        } else {
            policyChecks.append(
                "deployment_disabled"
            )
        }

        let summary: String
        let commandPreview: String

        if let configuration = decoded.configuration {
            summary =
                "Build the Swift package in explicit \(configuration.rawValue) configuration without deployment."
            commandPreview =
                "swift build -c \(configuration.rawValue)"
        } else {
            summary =
                "Run the project's normal \(request.config.buildDirComponent) build workflow from \(request.source.description)."
            commandPreview =
                request.source.arguments.isEmpty
                    ? "sbm"
                    : "sbm \(request.source.arguments.joined(separator: " "))"
        }

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot:
                workspace.rootURL.path,
            targetPaths: targetPaths,
            summary: summary,
            commandPreview: commandPreview,
            estimatedWriteCount:
                request.deploy
                    ? 2
                    : 1,
            estimatedRuntimeSeconds: 300,
            sideEffects: sideEffects,
            policyChecks: policyChecks,
            warnings: [
                "SwiftPM build execution is not confined by Agentic PathSandbox.",
                request.deploy
                    ? "The project-default build request may deploy outside the attached Agentic workspace."
                    : "No deployment is enabled for this build request.",
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

        let request = try buildRequest(
            decoded,
            workspace: workspace
        )

        let plan = try await Build.resolve(
            request
        )

        let execution = try await Build.execute(
            plan,
            captureOutput: true
        )

        let result = execution.build

        return try JSONToolBridge.encode(
            SwiftBuildToolOutput(
                configuration:
                    plan.request.config.buildDirComponent,
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
    }

    public func processResult(
        input _: JSONValue,
        output: JSONValue,
        workspace _: AgentWorkspace?
    ) -> AgentToolResultProcessing {
        guard let result =
            try? JSONToolBridge.decode(
                SwiftBuildToolOutput.self,
                from: output
            )
        else {
            return .none
        }

        var observations: [AgentToolResultObservation] = []

        if !result.stdout.isEmpty {
            observations.append(
                .init(
                    kind: .standard_output,
                    label: "stdout",
                    content: result.stdout
                )
            )
        }

        if !result.stderr.isEmpty {
            observations.append(
                .init(
                    kind: .standard_error,
                    label: "stderr",
                    content: result.stderr
                )
            )
        }

        return .init(
            projection: .init(
                status:
                    result.isSuccess
                        ? "passed"
                        : "failed",
                summary:
                    result.isSuccess
                        ? "Swift build completed successfully."
                        : "Swift build completed with a nonzero exit status.",
                facts: [
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
            ),
            observations: observations
        )
    }
}

private extension SwiftBuildTool {
    func buildRequest(
        _ input: SwiftBuildToolInput,
        workspace: AgentWorkspace
    ) throws -> Build.Request {
        guard let configuration = input.configuration else {
            return try SwiftBuildCommand.projectDefaultRequest(
                from: workspace.rootURL,
                updateBuiltOnSuccess: false
            )
        }

        let mode:
            Build.Config.Mode =
                switch configuration {
                case .debug:
                    .debug

                case .release:
                    .release
                }

        return Build.Request(
            project: workspace.rootURL,
            config: .init(
                mode: mode,
                updateBuiltOnSuccess: false
            ),
            deploy: false,
            source: .direct(
                arguments:
                    configuration == .debug
                        ? [
                            "--debug",
                        ]
                        : []
            )
        )
    }
}
