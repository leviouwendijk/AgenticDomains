import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Foundation

extension SwiftBuildTool {
    public var execution: AgentToolExecutionContract {
        .targetable
    }
    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: name
        )
        let project = context.workingDirectoryURL
            ?? workspace.rootURL
        let request = try targetedBuildRequest(
            input,
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

        if let configuration = input.configuration {
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
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: name
        )
        let project = context.workingDirectoryURL
            ?? workspace.rootURL
        let request = try targetedBuildRequest(
            input,
            project: project
        )
        do {
            let plan = try await Build.resolve(
                request
            )
            let execution = try await Build.execute(
                plan,
                captureOutput: true
            )
            let result = execution.build

            let output = SwiftBuildToolOutput(
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

            await observeSwiftBuildOutput(
                output,
                context: context
            )

            return output
        } catch BuildError.swiftFailed(
            let exitCode,
            let stdout,
            let stderr
        ) {
            let output = SwiftBuildToolOutput(
                        configuration:
                            request.config.buildDirComponent,
                        isSuccess: false,
                        exitCode: exitCode,
                        stdout: stdout,
                        stderr: stderr,
                        buildDirComponent:
                            request.config.buildDirComponent
                    )

            await observeSwiftBuildOutput(
                output,
                context: context
            )

            throw AgentToolReportedFailure(
                output: output
            )
        }
    }

    public func process(
        _ output: Output,
        input _: Input,
        context _: AgentToolExecutionContext
    ) -> AgentToolResultProjection? {
        .init(
            status: output.isSuccess ? "passed" : "failed",
            summary: output.isSuccess
                ? "Swift build completed successfully."
                : "Swift build completed with a nonzero exit status.",
            facts: [
                .init(label: "configuration", value: output.configuration),
                .init(label: "exit", value: "\(output.exitCode)"),
                .init(label: "build dir", value: output.buildDirComponent),
            ]
        )
    }

    private func observeSwiftBuildOutput(
        _ output: Output,
        context: AgentToolExecutionContext
    ) async {
        if !output.stdout.isEmpty {
            await context.observe(
                .init(
                    kind: .standard_output,
                    label: "stdout",
                    content: output.stdout
                )
            )
        }

        if !output.stderr.isEmpty {
            await context.observe(
                .init(
                    kind: .standard_error,
                    label: "stderr",
                    content: output.stderr
                )
            )
        }
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