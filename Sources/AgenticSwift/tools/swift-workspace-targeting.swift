import Agentic
import AgenticExecution
import AgenticWorkspace
import Executable
import Foundation
import Primitives
import Version

private struct SwiftWorkspaceExecution {
    let workspace: AgentWorkspace
    let projectRoot: URL

    static func resolve(
        _ context: AgentToolExecutionContext,
        toolName: String
    ) throws -> Self {
        let workspace = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: toolName
        )

        return .init(
            workspace: workspace,
            projectRoot:
                context.workingDirectoryURL
                    ?? workspace.rootURL
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

        let workspaceComponents =
            workspace.rootURL
                .standardizedFileURL
                .pathComponents
        let projectComponents =
            projectRoot
                .standardizedFileURL
                .pathComponents

        guard projectComponents.starts(
            with: workspaceComponents
        ) else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: "swift_app_bundle",
                operation: "resolve selected project root",
                exitCode: nil,
                signal: nil,
                detail:
                    "Selected project root is outside the attached Agentic workspace."
            )
        }

        let projectPrefix = projectComponents
            .dropFirst(
                workspaceComponents.count
            )
            .joined(
                separator: "/"
            )
        let workspaceRelativePath =
            projectPrefix.isEmpty
                ? normalized
                : "\(projectPrefix)/\(normalized)"
        let path = try workspace.resolve(
            workspaceRelativePath,
            type: .file
        )

        return try workspace.absoluteURL(
            for: path,
            type: .file
        )
    }
}

extension SwiftExecutableProductsTool {
    public var execution: AgentToolExecutionContract {
        .targetable
    }
    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        _ = input
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: [
                execution.projectRoot.path,
            ],
            summary:
                "Discover executable SwiftPM products at the selected workspace location.",
            commandPreview:
                "swift package dump-package",
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
        context: AgentToolExecutionContext
    ) async throws -> Output {
        _ = input
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let discovered: [ExecutableProduct]

        do {
            discovered = try await Products.executables(
                in: execution.projectRoot
            )
        } catch ProductsError.noExecutableProductsFound {
            discovered = []
        }

        return SwiftExecutableProductsToolOutput(
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
    public var execution: AgentToolExecutionContract {
        .targetable
    }
    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: [
                execution.projectPath("Package.resolved").path,
                execution.projectPath(
                    ".build",
                    isDirectory: true
                ).path,
            ],
            summary:
                "Update Swift package dependencies at the selected workspace location.",
            commandPreview:
                "swift package update",
            estimatedWriteCount: 2,
            estimatedRuntimeSeconds: 300,
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
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let result = try await Package.update(
            at: execution.projectRoot
        )

        guard result.exitCode == 0 else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: name,
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

        let output = SwiftPackageOperationToolOutput(
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

        await output.observe(
            in: context
        )

        return output
    }
}

extension SwiftResolveTool {
    public var execution: AgentToolExecutionContract {
        .targetable
    }
    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: [
                execution.projectPath("Package.resolved").path,
                execution.projectPath(
                    ".build",
                    isDirectory: true
                ).path,
            ],
            summary:
                "Resolve Swift package dependencies at the selected workspace location.",
            commandPreview:
                "swift package resolve",
            estimatedWriteCount: 2,
            estimatedRuntimeSeconds: 300,
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
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let result = try await Package.resolve(
            at: execution.projectRoot
        )

        guard result.exitCode == 0 else {
            throw AgenticSwiftToolError.operationFailed(
                toolName: name,
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

        let output = SwiftPackageOperationToolOutput(
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

        await output.observe(
            in: context
        )

        return output
    }
}

extension SwiftCleanTool {
    public var execution: AgentToolExecutionContract {
        .targetable
    }
    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: [
                execution.projectPath(
                    ".build",
                    isDirectory: true
                ).path,
            ],
            summary:
                "Clean SwiftPM build artifacts at the selected workspace location.",
            commandPreview:
                "swift package clean",
            estimatedWriteCount: 1,
            sideEffects: [
                "Removes SwiftPM build artifacts under .build.",
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
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        try await Build.clean(
            at: execution.projectRoot
        )

        return SwiftCleanToolOutput(
            status: "passed"
        )
    }
}

extension SwiftVersionTool {
    public var execution: AgentToolExecutionContract {
        .targetable
    }
    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: [
                execution.projectPath("build-object.pkl").path,
                execution.projectPath("compiled.pkl").path,
            ],
            summary:
                "Inspect Swift project version state at the selected workspace location.",
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
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let snapshot = try await ExecutableVersion.inspect(
            at: execution.projectRoot
        )

        return SwiftVersionToolOutput(
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
    public var execution: AgentToolExecutionContract {
        .targetable
    }
    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: [
                execution.projectPath("build-object.pkl").path,
            ],
            summary:
                "Increment Swift release \(input.level.rawValue) version at the selected workspace location.",
            estimatedWriteCount: 1,
            sideEffects: [
                "Updates the release version in build-object.pkl.",
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
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let result = try ExecutableVersion.incrementRelease(
            at: execution.projectRoot,
            level: input.level
        )

        return SwiftIncrementVersionToolOutput(
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
    public var execution: AgentToolExecutionContract {
        .targetable
    }
    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: [
                execution.projectRoot.path,
            ],
            summary:
                input.dryRun == true
                    ? "Inspect SwiftPM processes for the selected workspace location without signaling them."
                    : "Terminate detected SwiftPM process trees for the selected workspace location.",
            commandPreview:
                input.dryRun == true
                    ? "kill-swiftpm --dry-run"
                    : "kill-swiftpm",
            sideEffects:
                input.dryRun == true
                    ? []
                    : [
                        "Sends termination signals to detected Swift/SwiftPM process trees.",
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
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let processes = try await SwiftPMProcesses().killAll(
            force: input.force ?? false,
            dryRun: input.dryRun ?? false,
            cwd: execution.projectRoot
        )

        return SwiftKillSwiftPMToolOutput(
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
    public var execution: AgentToolExecutionContract {
        .targetable
    }
    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths:
                input.local == true
                    ? [
                        execution.projectPath(
                            ".build",
                            isDirectory: true
                        ).path,
                    ]
                    : [
                        execution.projectPath(
                            ".build",
                            isDirectory: true
                        ).path,
                        BuildLibrary.defaultModulesRoot.path,
                    ],
            summary:
                "Build Swift library distribution artifacts at the selected workspace location.",
            estimatedRuntimeSeconds: 300,
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
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
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

        return SwiftBuildLibraryToolOutput(
            package: result.packageName,
            artifacts: result.artifactsDir.path,
            buildDir: result.builtDir.path
        )
    }
}

extension SwiftBuildObjectInitTool {
    public var execution: AgentToolExecutionContract {
        .targetable
    }
    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: [
                execution.projectPath("build-object.pkl").path,
                execution.projectPath("compiled.pkl").path,
            ],
            summary:
                "Initialize Swift build-object configuration at the selected workspace location.",
            estimatedWriteCount: 2,
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "typed_build_object_initialization",
            ]
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
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

        return SwiftBuildObjectInitToolOutput(
            configuration: result.configurationURL.path,
            compiled: result.compiledURL.path,
            createdConfiguration: result.createdConfiguration,
            createdCompiled: result.createdCompiled
        )
    }
}

extension SwiftBuildObjectModernizeTool {
    public var execution: AgentToolExecutionContract {
        .targetable
    }
    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths:
                input.backup == false
                    ? [
                        execution.projectPath("build-object.pkl").path,
                    ]
                    : [
                        execution.projectPath("build-object.pkl").path,
                        execution.projectPath("build-object.pkl.bak").path,
                    ],
            summary:
                "Modernize legacy Swift build-object configuration at the selected workspace location.",
            estimatedWriteCount:
                input.backup == false
                    ? 1
                    : 2,
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "typed_build_object_modernization",
            ]
        )
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let result = try BuildObjectLifecycle.modernize(
            at: execution.projectRoot,
            backup: input.backup ?? true
        )

        return SwiftBuildObjectModernizeToolOutput(
            path: result.configurationURL.path,
            name: result.name,
            modernized: result.modernized,
            backup: result.backupURL?.path
        )
    }
}

extension SwiftAppBundleTool {
    public var execution: AgentToolExecutionContract {
        .targetable
    }
    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let appName =
            input.appName
                ?? input.target
                ?? execution.projectRoot.lastPathComponent

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: [
                execution.projectPath(
                    "\(appName).app",
                    isDirectory: true
                ).path,
            ],
            summary:
                "Create or refresh the selected project's app bundle.",
            estimatedWriteCount: 4,
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
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
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

        return SwiftAppBundleToolOutput(
            app: result.appDirectory.path,
            buildDir: result.buildDirectory.path,
            appName: result.appName,
            target: result.target
        )
    }
}

extension SwiftDeployTool {
    public var execution: AgentToolExecutionContract {
        .targetable
    }
    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let resolved = try await targetedDeployResolution(
            input,
            project: execution.projectRoot
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: [
                resolved.destination.path,
            ],
            summary:
                "Deploy Swift executable product(s) from the selected workspace location: \(resolved.plan.selectedProductNames.joined(separator: ", ")).",
            commandPreview:
                "deploy \(input.configuration.rawValue) -> \(resolved.destination.path)",
            estimatedWriteCount: max(
                1,
                resolved.plan.selectedProductNames.count * 2
            ),
            estimatedRuntimeSeconds: 60,
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
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
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

        return SwiftDeployToolOutput(
                configuration: input.configuration.rawValue,
                destination: resolved.destination.path,
                products: resolved.plan.selectedProductNames
            )
    }

    private func targetedDeployResolution(
        _ input: SwiftDeployToolInput,
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
    public var execution: AgentToolExecutionContract {
        .targetable
    }
    public func preflight(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
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

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: [
                execution.projectPath(
                    ".build",
                    isDirectory: true
                ).path,
            ],
            summary:
                "Run Swift executable product '\(input.product)' at the selected workspace location.",
            commandPreview:
                "swift run \(input.product)\(suffix)",
            estimatedWriteCount: 1,
            estimatedRuntimeSeconds: 300,
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
        context: AgentToolExecutionContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
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
                toolName: name,
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

        let output = SwiftRunProductToolOutput(
                product: result.product,
                isSuccess: result.isSuccess,
                exitCode: result.exitCode,
                signal: result.signal,
                stdout: result.stdoutText,
                stderr: result.stderrText
        )

        if !output.stdout.isEmpty {
            await context.observe(
                .init(kind: .standard_output, label: "stdout", content: output.stdout)
            )
        }
        if !output.stderr.isEmpty {
            await context.observe(
                .init(kind: .standard_error, label: "stderr", content: output.stderr)
            )
        }

        return output
    }
}


extension SwiftUpdateTool {
    public func process(
        _ output: Output,
        input _: Input,
        context _: AgentToolExecutionContext
    ) -> AgentToolResultProjection? {
        output.projection
    }
}

extension SwiftResolveTool {
    public func process(
        _ output: Output,
        input _: Input,
        context _: AgentToolExecutionContext
    ) -> AgentToolResultProjection? {
        output.projection
    }
}

extension SwiftDeployTool {
    public func process(
        _ output: Output,
        input _: Input,
        context _: AgentToolExecutionContext
    ) -> AgentToolResultProjection? {
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
        input _: Input,
        context _: AgentToolExecutionContext
    ) -> AgentToolResultProjection? {
        var facts: [AgentToolResultProjection.Fact] = [
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
