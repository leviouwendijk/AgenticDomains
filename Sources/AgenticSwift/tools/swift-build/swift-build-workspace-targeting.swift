import Agentic
import Workspace
import Executable
import Foundation
import Primitives

extension SwiftLang.Tools.Build {
    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )
        let project = workspace.absoluteURL
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

        let steps = buildSteps(input)
        if steps.test {
            targetPaths.append(project.appendingPathComponent(Tests.conventionalDirectory, isDirectory: true).path)
        }

        var sideEffects = (steps.test ? [
            "Runs the Tests/ primary first; a failure stops the build.",
        ] : []) + tidySteps(input).sideEffects + (steps.bench ? [
            "Runs the Benchmarks/ primary after a successful build.",
        ] : []) + [
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
        var commandPreview: String

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
        let flags = stepFlags(input)
        if !flags.isEmpty {
            commandPreview += " " + flags.joined(separator: " ")
        }

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: summary,
            access: .init(
                targets: targetPaths
            ),
            estimates: .init(
                write: .init(
                    count: request.deploy
                        ? 2
                        : 1
                ),
                runtime: 300
            ),
            preview: .init([
                .command(.init(commandPreview)),
            ]),
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
        in context: ToolContext
    ) async throws -> Output {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )
        let project = workspace.absoluteURL
        let request = try targetedBuildRequest(
            input,
            project: project
        )
        let steps = buildSteps(input)
        let buffer = TextBuffer(limit: 32_768)

        func failure(
            exitCode: Int,
            stdout: String,
            stderr: String
        ) -> AgentToolReportedFailure<Output> {
            AgentToolReportedFailure(
                output: Output(
                    configuration: request.config.buildDirComponent,
                    isSuccess: false,
                    exitCode: exitCode,
                    stdout: stdout,
                    stderr: stderr,
                    buildDirComponent: request.config.buildDirComponent,
                    steps: Self.report(buffer)
                )
            )
        }

        do {
            try await steps.before(at: project, output: buffer.sink)
        } catch {
            throw failure(exitCode: 1, stdout: "", stderr: error.localizedDescription)
        }

        let result: Executable.Build.BuildResult
        let configuration: String
        do {
            let plan = try await Executable.Build.resolve(
                request
            )
            let execution = try await Executable.Build.execute(
                plan,
                captureOutput: true
            )
            result = execution.build
            configuration = plan.request.config.buildDirComponent
        } catch BuildError.swiftFailed(
            let exitCode,
            let stdout,
            let stderr
        ) {
            throw failure(exitCode: exitCode, stdout: stdout, stderr: stderr)
        }

        let stdout = String(decoding: result.stdout, as: UTF8.self)
        let stderr = String(decoding: result.stderr, as: UTF8.self)
        if result.exitCode == 0 {
            do {
                try await steps.after(at: project, output: buffer.sink)
            } catch {
                throw failure(exitCode: 1, stdout: stdout, stderr: error.localizedDescription)
            }
        }

        return Output(
            configuration: configuration,
            isSuccess: result.exitCode == 0,
            exitCode: Int(result.exitCode),
            stdout: stdout,
            stderr: stderr,
            buildDirComponent: result.buildDirComponent,
            steps: Self.report(buffer)
        )
    }

    public func process(
        _ output: Output,
        input _: Input
    ) -> ToolExecution.Projection? {
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


    private func buildSteps(
        _ input: Input
    ) -> SwiftBuildSteps {
        SwiftBuildSteps(
            test: input.test == true,
            bench: input.bench == true,
            cleanBefore: input.cleanBefore == true,
            wipeBefore: input.wipeBefore == true,
            clean: input.clean == true,
            wipe: input.wipe == true
        )
    }

    private func tidySteps(
        _ input: Input
    ) -> SwiftTidySteps {
        SwiftTidySteps(cleanBefore: input.cleanBefore, wipeBefore: input.wipeBefore, clean: input.clean, wipe: input.wipe)
    }

    /// The sbm flags the steps correspond to, for the preview.
    private func stepFlags(
        _ input: Input
    ) -> [String] {
        [
            (input.test, "--test"),
            (input.bench, "--bench"),
            (input.cleanBefore, "--clean-before"),
            (input.wipeBefore, "--wipe-before"),
            (input.clean, "--clean"),
            (input.wipe, "--wipe"),
        ]
        .filter { $0.0 == true }
        .map(\.1)
    }

    private static func report(
        _ buffer: TextBuffer
    ) -> String? {
        buffer.isEmpty ? nil : SwiftTidySteps.report(buffer)
    }

    private func targetedBuildRequest(
        _ input: Input,
        project: URL
    ) throws -> Executable.Build.Request {
        guard let configuration = input.configuration else {
            return try SwiftBuildCommand.projectDefaultRequest(
                from: project
            )
        }

        let mode: Executable.Build.Config.Mode =
            switch configuration {
            case .debug:
                .debug

            case .release:
                .release
            }

        return Executable.Build.Request(
            project: project,
            config: .init(
                mode: mode
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
