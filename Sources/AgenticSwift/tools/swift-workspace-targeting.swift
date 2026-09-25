import Agentic
import AgenticExecution
import Workspace
import Executable
import Foundation
import Primitives
import Version

private struct SwiftWorkspaceExecution {
    let workspace: WorkspaceContext
    let projectRoot: URL

    static func resolve(
        _ context: WorkspaceContext?,
        toolName: String
    ) throws -> Self {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context,
            toolName: toolName
        )

        return .init(
            workspace: workspace,
            projectRoot: workspace.absoluteURL
        )
    }

    func projectPath(
        _ relativePath: String,
        isDirectory: Bool = false
    ) -> URL {
        projectRoot.appendingPathComponent(
            relativePath,
            isDirectory: isDirectory
        )
    }

    func projectFile(
        _ rawPath: String
    ) throws -> URL {
        let normalized = rawPath.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let components = normalized.split(
            separator: "/",
            omittingEmptySubsequences: false
        )

        guard !normalized.isEmpty,
              !normalized.hasPrefix("/"),
              !components.contains("..")
        else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: "swift_app_bundle",
                operation: "resolve project-relative file path",
                exitCode: nil,
                signal: nil,
                detail:
                    "Project-relative paths cannot be empty, absolute, or contain parent traversal: \(rawPath)"
            )
        }

        let candidate = projectRoot
            .appendingPathComponent(normalized)
            .standardizedFileURL
        let rootComponents = projectRoot
            .standardizedFileURL
            .pathComponents

        guard candidate.pathComponents.starts(with: rootComponents) else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: "swift_app_bundle",
                operation: "resolve project-relative file path",
                exitCode: nil,
                signal: nil,
                detail: "Resolved path escaped the selected Swift package root."
            )
        }

        return candidate
    }
}

extension SwiftExecutableProductsTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        _ = input
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: "Discover executable SwiftPM products at the selected workspace location.",
            access: .init(
                targets: [
                    execution.projectRoot.path
                ]
            ),
            preview: .init(
                command: "swift package dump-package"
            ),
            sideEffects: [],
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "swift_package_introspection",
            ]
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        _ = input
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let discovered: [ExecutableProduct]

        do {
            discovered = try await Products.executables(
                in: execution.projectRoot
            )
        } catch ProductsError.noExecutableProductsFound {
            discovered = []
        }

        return Output(
                products:
                    discovered
                        .sorted {
                            $0.name < $1.name
                        }
                        .map {
                            .init(
                                name: $0.name,
                                targets: $0.targets.sorted()
                            )
                        }
            )
    }
}

extension SwiftUpdateTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: "Update Swift package dependencies at the selected workspace location.",
            access: .init(
                targets: [
                    execution.projectPath("Package.resolved").path,
                    execution.projectPath(
                        ".build",
                        isDirectory: true
                    ).path,
                ]
            ),
            estimates: .init(
                write: .init(
                    count: 2
                ),
                runtime: 300
            ),
            preview: .init(
                command: "swift package update"
            ),
            sideEffects: [
                "May update Package.resolved.",
                "May fetch package dependencies over the network.",
                "May update SwiftPM state under .build.",
            ],
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "typed_swift_package_update",
                "human_review_required",
            ],
            warnings: [
                "SwiftPM dependency update is not confined by Agentic PathSandbox."
            ]
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let result = try await Package.update(
            at: execution.projectRoot
        )

        guard result.exitCode == 0 else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: Self.definition.identifier.rawValue,
                operation: "swift package update",
                exitCode: Int(result.exitCode),
                signal: nil,
                detail: String(
                    String(
                        decoding: result.stderr,
                        as: UTF8.self
                    ).prefix(16_384)
                )
            )
        }

        let output = Output(
            operation: "update",
            isSuccess: true,
            exitCode: Int(result.exitCode),
            stdout: String(
                decoding: result.stdout,
                as: UTF8.self
            ),
            stderr: String(
                decoding: result.stderr,
                as: UTF8.self
            )
        )

        return output
    }
}

extension SwiftResolveTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: "Resolve Swift package dependencies at the selected workspace location.",
            access: .init(
                targets: [
                    execution.projectPath("Package.resolved").path,
                    execution.projectPath(
                        ".build",
                        isDirectory: true
                    ).path,
                ]
            ),
            estimates: .init(
                write: .init(
                    count: 2
                ),
                runtime: 300
            ),
            preview: .init(
                command: "swift package resolve"
            ),
            sideEffects: [
                "May update Package.resolved.",
                "May fetch package dependencies over the network.",
                "May update SwiftPM state under .build.",
            ],
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "typed_swift_package_resolve",
                "human_review_required",
            ],
            warnings: [
                "SwiftPM dependency resolution is not confined by Agentic PathSandbox."
            ]
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let result = try await Package.resolve(
            at: execution.projectRoot
        )

        guard result.exitCode == 0 else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: Self.definition.identifier.rawValue,
                operation: "swift package resolve",
                exitCode: Int(result.exitCode),
                signal: nil,
                detail: String(
                    String(
                        decoding: result.stderr,
                        as: UTF8.self
                    ).prefix(16_384)
                )
            )
        }

        let output = Output(
            operation: "resolve",
            isSuccess: true,
            exitCode: Int(result.exitCode),
            stdout: String(
                decoding: result.stdout,
                as: UTF8.self
            ),
            stderr: String(
                decoding: result.stderr,
                as: UTF8.self
            )
        )

        return output
    }
}

extension SwiftCleanTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: "Clean SwiftPM build artifacts at the selected workspace location.",
            access: .init(
                targets: [
                    execution.projectPath(
                        ".build",
                        isDirectory: true
                    ).path
                ]
            ),
            estimates: .init(
                write: .init(
                    count: 1
                )
            ),
            preview: .init(
                command: "swift package clean"
            ),
            sideEffects: [
                "Removes SwiftPM build artifacts under .build."
            ],
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "typed_swift_clean",
                "human_review_required",
            ]
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        try await Build.clean(
            at: execution.projectRoot
        )

        return Output(
            status: "passed"
        )
    }
}

extension SwiftVersionTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: "Inspect Swift project version state at the selected workspace location.",
            access: .init(
                targets: [
                    execution.projectPath("build-object.pkl").path,
                    execution.projectPath("compiled.pkl").path,
                ]
            ),
            sideEffects: [],
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "typed_executable_version_inspection",
            ]
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let snapshot = try await ExecutableVersion.inspect(
            at: execution.projectRoot
        )

        return Output(
                name: snapshot.name,
                types: snapshot.types,
                compiled: snapshot.compiled.string(
                    prefixStyle: .short,
                    prefixSpace: false
                ),
                release: snapshot.release.string(
                    prefixStyle: .short,
                    prefixSpace: false
                ),
                ahead: snapshot.ahead,
                behind: snapshot.behind
            )
    }
}

extension SwiftIncrementVersionTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary:
                "Increment Swift release \(input.level.rawValue) version at the selected workspace location.",
            access: .init(
                targets: [
                    execution.projectPath("build-object.pkl").path
                ]
            ),
            estimates: .init(
                write: .init(
                    count: 1
                )
            ),
            sideEffects: [
                "Updates the release version in build-object.pkl."
            ],
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "typed_executable_version_increment",
            ]
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let result = try ExecutableVersion.incrementRelease(
            at: execution.projectRoot,
            level: input.level
        )

        return Output(
            before: result.before.string(
                prefixStyle: .short,
                prefixSpace: false
            ),
            after: result.after.string(
                prefixStyle: .short,
                prefixSpace: false
            ),
            level: result.level.rawValue,
            path: result.configurationURL.path
        )
    }
}

extension SwiftKillSwiftPMTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: input.dryRun == true
                ? "Inspect SwiftPM processes for the selected workspace location without signaling them."
                : "Terminate detected SwiftPM process trees for the selected workspace location.",
            access: .init(
                targets: [
                    execution.projectRoot.path
                ]
            ),
            preview: .init(
                command: input.dryRun == true
                    ? "kill-swiftpm --dry-run"
                    : "kill-swiftpm"
            ),
            sideEffects: input.dryRun == true
                ? []
                : [
                    "Sends termination signals to detected Swift/SwiftPM process trees."
                ],
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "typed_swiftpm_process_management",
                "human_review_required",
            ]
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let processes = try await SwiftPMProcesses().killAll(
            force: input.force ?? false,
            dryRun: input.dryRun ?? false,
            cwd: execution.projectRoot
        )

        return Output(
            count: String(processes.count),
            dryRun: input.dryRun ?? false,
            processes: processes.map { process in
                .init(
                    pid: String(process.pid),
                    command: process.commandLine
                )
            }
        )
    }
}

extension SwiftBuildLibraryTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: "Build Swift library distribution artifacts at the selected workspace location.",
            access: .init(
                targets: input.local == true
                    ? [
                        execution.projectPath(
                            ".build",
                            isDirectory: true
                        ).path
                    ]
                    : [
                        execution.projectPath(
                            ".build",
                            isDirectory: true
                        ).path,
                        BuildLibrary.defaultModulesRoot.path,
                    ]
            ),
            estimates: .init(
                runtime: 300
            ),
            sideEffects: [
                "Runs SwiftPM builds.",
                "May export module/library artifacts outside the workspace.",
            ],
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "typed_build_library",
                "human_review_required",
            ]
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let configuration =
            input.configuration
                ?? .release
        let config = Build.Config(
            mode:
                configuration == .debug
                    ? .debug
                    : .release,
            updateBuiltOnSuccess: false
        )
        let result = try await BuildLibrary.buildAndExport(
            at: execution.projectRoot,
            config: config,
            local: input.local ?? false,
            modulesRoot: BuildLibrary.defaultModulesRoot
        )

        return Output(
            package: result.packageName,
            artifacts: result.artifactsDir.path,
            buildDir: result.builtDir.path
        )
    }
}

extension SwiftBuildObjectInitTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: "Initialize Swift build-object configuration at the selected workspace location.",
            access: .init(
                targets: [
                    execution.projectPath("build-object.pkl").path,
                    execution.projectPath("compiled.pkl").path,
                ]
            ),
            estimates: .init(
                write: .init(
                    count: 2
                )
            ),
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "typed_build_object_initialization",
            ]
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        let result: BuildObjectLifecycle.InitializeResult

        if input.empty == true {
            result = try BuildObjectLifecycle.initializeEmpty(
                at: execution.projectRoot
            )
        } else {
            result = try BuildObjectLifecycle.initialize(
                at: execution.projectRoot,
                request: .init(
                    name: input.name,
                    types: input.types ?? ["binary"],
                    details: input.details ?? "",
                    author: input.author,
                    update: input.update ?? "",
                    createCompiled:
                        input.createCompiled
                            ?? true
                )
            )
        }

        return Output(
            configuration: result.configurationURL.path,
            compiled: result.compiledURL.path,
            createdConfiguration: result.createdConfiguration,
            createdCompiled: result.createdCompiled
        )
    }
}

extension SwiftBuildObjectModernizeTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary:
                "Modernize legacy Swift build-object configuration at the selected workspace location.",
            access: .init(
                targets: input.backup == false
                    ? [
                        execution.projectPath("build-object.pkl").path
                    ]
                    : [
                        execution.projectPath("build-object.pkl").path,
                        execution.projectPath("build-object.pkl.bak").path,
                    ]
            ),
            estimates: .init(
                write: .init(
                    count: input.backup == false
                        ? 1
                        : 2
                )
            ),
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "typed_build_object_modernization",
            ]
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let result = try BuildObjectLifecycle.modernize(
            at: execution.projectRoot,
            backup: input.backup ?? true
        )

        return Output(
            path: result.configurationURL.path,
            name: result.name,
            modernized: result.modernized,
            backup: result.backupURL?.path
        )
    }
}

extension SwiftAppBundleTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let appName =
            input.appName
                ?? input.target
                ?? execution.projectRoot.lastPathComponent

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: "Create or refresh the selected project's app bundle.",
            access: .init(
                targets: [
                    execution.projectPath(
                        "\(appName).app",
                        isDirectory: true
                    ).path
                ]
            ),
            estimates: .init(
                write: .init(
                    count: 4
                )
            ),
            sideEffects: [
                "Creates or replaces app-bundle symlinks and Info.plist materialization.",
                "Uses already-built artifacts under .build and does not run a build itself.",
            ],
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "typed_app_bundle_creation",
            ]
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let plist =
            try input.plist.map {
                try execution.projectFile(
                    $0
                )
            }
        let result = try await AppBundleCreation.create(
            .init(
                project: execution.projectRoot,
                appName: input.appName,
                target: input.target,
                configuration:
                    input.configuration == .debug
                        ? .debug
                        : .release,
                plist: plist,
                plistSymlink:
                    input.plistSymlink
                        ?? true,
                resourcesBundle:
                    input.resourcesBundle
            )
        )

        return Output(
            app: result.appDirectory.path,
            buildDir: result.buildDirectory.path,
            appName: result.appName,
            target: result.target
        )
    }
}

extension SwiftDeployTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let resolved = try await targetedDeployResolution(
            input,
            project: execution.projectRoot
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary:
                "Deploy Swift executable product(s) from the selected workspace location: \(resolved.plan.selectedProductNames.joined(separator: ", ")).",
            access: .init(
                targets: [
                    resolved.destination.path
                ]
            ),
            estimates: .init(
                write: .init(
                    count: max(
                        1,
                        resolved.plan.selectedProductNames.count * 2
                    )
                ),
                runtime: 60
            ),
            preview: .init(
                command: "deploy \(input.configuration.rawValue) -> \(resolved.destination.path)"
            ),
            sideEffects: [
                "Moves built executable artifacts from .build into the deployment destination.",
                "Replaces existing deployed products when present.",
                "Writes per-product deployment metadata using Executable.Deploy.",
            ],
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "typed_swift_deploy",
                "executable_products_resolved",
                "shared_executable_deploy_mechanics",
                "human_review_required",
            ],
            warnings: [
                "The canonical Executable deployment directory is outside the attached Agentic workspace."
            ]
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let resolved = try await targetedDeployResolution(
            input,
            project: execution.projectRoot
        )

        try Deploy.selected(
            from: execution.projectRoot,
            config: resolved.plan.request.config,
            to: resolved.destination,
            products: resolved.plan.selectedProductNames,
            perProductDestinations:
                resolved.plan.perProductDestinations
        )

        return Output(
                configuration: input.configuration.rawValue,
                destination: resolved.destination.path,
                products: resolved.plan.selectedProductNames
            )
    }

    private func targetedDeployResolution(
        _ input: Input,
        project: URL
    ) async throws -> (
        destination: URL,
        plan: Build.Plan
    ) {
        let mode: Build.Config.Mode =
            switch input.configuration {
            case .debug:
                .debug

            case .release:
                .release
            }
        let destination =
            Build.defaultDeploymentDirectory
        let request = Build.Request(
            project: project,
            config: .init(
                mode: mode,
                updateBuiltOnSuccess: false
            ),
            destination: destination,
            deploy: true,
            selection: .init(
                products: Set(input.products)
            ),
            source: .direct(
                arguments: []
            )
        )

        return (
            destination,
            try await Build.resolve(
                request
            )
        )
    }
}

extension SwiftRunProductTool {
    public func preflight(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let available: [ExecutableProduct]

        do {
            available = try await Products.executables(
                in: execution.projectRoot
            )
        } catch ProductsError.noExecutableProductsFound {
            available = []
        }

        let names =
            available
                .map(\.name)
                .sorted()

        guard names.contains(
            input.product
        ) else {
            throw SwiftRunError.productNotFound(
                product: input.product,
                available: names
            )
        }

        let suffix =
            input.verbose
                ? " --verbose"
                : ""

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary:
                "Run Swift executable product '\(input.product)' at the selected workspace location.",
            access: .init(
                targets: [
                    execution.projectPath(
                        ".build",
                        isDirectory: true
                    ).path
                ]
            ),
            estimates: .init(
                write: .init(
                    count: 1
                ),
                runtime: 300
            ),
            preview: .init(
                command: "swift run \(input.product)\(suffix)"
            ),
            sideEffects: [
                "May build the selected executable product under .build before execution.",
                "Executes repository-owned code with the current host filesystem, process, environment, and network permissions.",
                "Execution is managed by Processes with an output limit and timeout.",
            ],
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "executable_product_discovered",
                "no_model_supplied_process_arguments",
                "managed_process_execution",
                "human_review_required",
            ],
            warnings: [
                "Executed repository code is not confined by Agentic PathSandbox."
            ]
        )
    }

    public func call(
        _ input: Input,
        workspace context: WorkspaceContext?
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: Self.definition.identifier.rawValue
        )
        let arguments =
            input.verbose
                ? [
                    "--verbose",
                ]
                : []
        let result = try await SwiftRun.run(
            .init(
                product: input.product,
                arguments: arguments
            ),
            at: execution.projectRoot,
            options: .init(
                outputLimit:
                    4 * 1024 * 1024,
                timeout:
                    .seconds(300)
            )
        )

        guard result.isSuccess else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: Self.definition.identifier.rawValue,
                operation:
                    "run Swift executable product '\(result.product)'",
                exitCode:
                    result.exitCode.map(Int.init),
                signal:
                    result.signal.map(Int.init),
                detail:
                    String(
                        (
                            result.stderrText.isEmpty
                                ? result.stdoutText
                                : result.stderrText
                        ).prefix(16_384)
                    )
            )
        }

        let output = Output(
                product: result.product,
                isSuccess: result.isSuccess,
                exitCode: result.exitCode,
                signal: result.signal,
                stdout: result.stdoutText,
                stderr: result.stderrText
        )


        return output
    }
}


extension SwiftUpdateTool {
    public func process(
        _ output: Output,
        input _: Input
    ) -> ToolCall.ResultProjection? {
        output.projection
    }
}

extension SwiftResolveTool {
    public func process(
        _ output: Output,
        input _: Input
    ) -> ToolCall.ResultProjection? {
        output.projection
    }
}

extension SwiftDeployTool {
    public func process(
        _ output: Output,
        input _: Input
    ) -> ToolCall.ResultProjection? {
        .init(
            status: "passed",
            summary: "Swift deployment completed successfully.",
            facts: [
                .init(label: "configuration", value: output.configuration),
                .init(label: "destination", value: output.destination),
                .init(label: "products", value: output.products.joined(separator: ", ")),
            ]
        )
    }
}

extension SwiftRunProductTool {
    public func process(
        _ output: Output,
        input _: Input
    ) -> ToolCall.ResultProjection? {
        var facts: [ToolCall.ResultProjection.Fact] = [
            .init(label: "product", value: output.product)
        ]

        if let exitCode = output.exitCode {
            facts.append(.init(label: "exit", value: "\(exitCode)"))
        }
        if let signal = output.signal {
            facts.append(.init(label: "signal", value: "\(signal)"))
        }

        return .init(
            status: output.isSuccess ? "passed" : "failed",
            summary: output.isSuccess
                ? "Swift product '\(output.product)' completed successfully."
                : "Swift product '\(output.product)' completed unsuccessfully.",
            facts: facts
        )
    }
}
