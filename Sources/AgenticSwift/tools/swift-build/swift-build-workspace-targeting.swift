import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Foundation
import Primitives

extension SwiftBuildTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            SwiftBuildToolInput.self,
            from: input
        )
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: name
        )
        let project = context.workingDirectoryURL
            ?? workspace.rootURL
        let request = try targetedBuildRequest(
            decoded,
            project: project
        )

        var targetPaths = [
            project.appendingPathComponent(
                ".build",
                isDirectory: true
            ).path,
        ]

        var sideEffects = [
            "Writes SwiftPM build artifacts under .build.",
            "SwiftPM may resolve or fetch package dependencies.",
            "Package or build-plugin code may execute with the current host permissions.",
            "Executable built-version snapshot bookkeeping is disabled for this invocation.",
        ]

        var policyChecks = [
            "workspace_required",
            "workspace_location_selected",
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
                "Build the selected Swift package in explicit \(configuration.rawValue) configuration without deployment."
            commandPreview =
                "swift build -c \(configuration.rawValue)"
        } else {
            summary =
                "Run the selected project's normal \(request.config.buildDirComponent) build workflow from \(request.source.description)."
            commandPreview =
                request.source.arguments.isEmpty
                    ? "sbm"
                    : "sbm \(request.source.arguments.joined(separator: " "))"
        }

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: workspace.rootURL.path,
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
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftBuildToolInput.self,
            from: input
        )
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: name
        )
        let project = context.workingDirectoryURL
            ?? workspace.rootURL
        let request = try targetedBuildRequest(
            decoded,
            project: project
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
                    Int(result.exitCode),
                stdout:
                    String(
                        decoding: result.stdout,
                        as: UTF8.self
                    ),
                stderr:
                    String(
                        decoding: result.stderr,
                        as: UTF8.self
                    ),
                buildDirComponent:
                    result.buildDirComponent
            )
        )
    }

    private func targetedBuildRequest(
        _ input: SwiftBuildToolInput,
        project: URL
    ) throws -> Build.Request {
        guard let configuration = input.configuration else {
            return try SwiftBuildCommand.projectDefaultRequest(
                from: project,
                updateBuiltOnSuccess: false
            )
        }

        let mode: Build.Config.Mode =
            switch configuration {
            case .debug:
                .debug

            case .release:
                .release
            }

        return Build.Request(
            project: project,
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
