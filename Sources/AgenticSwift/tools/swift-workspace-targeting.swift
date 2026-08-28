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

extension SwiftExecutableProductsTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
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
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
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

        return try JSONToolBridge.encode(
            SwiftExecutableProductsToolOutput(
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
        )
    }
}

extension SwiftUpdateTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input _: JSONValue,
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
        input _: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
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

        return try JSONToolBridge.encode(
            SwiftPackageOperationToolOutput(
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
        )
    }
}

extension SwiftResolveTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input _: JSONValue,
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
        input _: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
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

        return try JSONToolBridge.encode(
            SwiftPackageOperationToolOutput(
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
        )
    }
}

extension SwiftCleanTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input _: JSONValue,
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
        input _: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        try await Build.clean(
            at: execution.projectRoot
        )

        return .object([
            "status": .string("passed"),
        ])
    }
}

extension SwiftVersionTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input _: JSONValue,
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
        input _: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let snapshot = try await ExecutableVersion.inspect(
            at: execution.projectRoot
        )

        return try JSONToolBridge.encode(
            SwiftVersionToolOutput(
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
        )
    }
}

extension SwiftIncrementVersionTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            SwiftIncrementVersionToolInput.self,
            from: input
        )
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
                "Increment Swift release \(decoded.level.rawValue) version at the selected workspace location.",
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
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftIncrementVersionToolInput.self,
            from: input
        )
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let result = try ExecutableVersion.incrementRelease(
            at: execution.projectRoot,
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

extension SwiftKillSwiftPMTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            SwiftKillSwiftPMToolInput.self,
            from: input
        )
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
                decoded.dryRun == true
                    ? "Inspect SwiftPM processes for the selected workspace location without signaling them."
                    : "Terminate detected SwiftPM process trees for the selected workspace location.",
            commandPreview:
                decoded.dryRun == true
                    ? "kill-swiftpm --dry-run"
                    : "kill-swiftpm",
            sideEffects:
                decoded.dryRun == true
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
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftKillSwiftPMToolInput.self,
            from: input
        )
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let processes = try await SwiftPMProcesses().killAll(
            force: decoded.force ?? false,
            dryRun: decoded.dryRun ?? false,
            cwd: execution.projectRoot
        )

        return .object([
            "count": .string(String(processes.count)),
            "dryRun": .bool(decoded.dryRun ?? false),
            "processes": .array(
                processes.map {
                    .object([
                        "pid": .string(String($0.pid)),
                        "command": .string($0.commandLine),
                    ])
                }
            ),
        ])
    }
}

extension SwiftBuildLibraryTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            SwiftBuildLibraryToolInput.self,
            from: input
        )
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths:
                decoded.local == true
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
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftBuildLibraryToolInput.self,
            from: input
        )
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let configuration =
            decoded.configuration
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
            local: decoded.local ?? false,
            modulesRoot: BuildLibrary.defaultModulesRoot
        )

        return .object([
            "package": .string(result.packageName),
            "artifacts": .string(result.artifactsDir.path),
            "buildDir": .string(result.builtDir.path),
        ])
    }
}

extension SwiftBuildObjectInitTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input _: JSONValue,
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
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftBuildObjectInitToolInput.self,
            from: input
        )
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        let result: BuildObjectLifecycle.InitializeResult

        if decoded.empty == true {
            result = try BuildObjectLifecycle.initializeEmpty(
                at: execution.projectRoot
            )
        } else {
            result = try BuildObjectLifecycle.initialize(
                at: execution.projectRoot,
                request: .init(
                    name: decoded.name,
                    types: decoded.types ?? ["binary"],
                    details: decoded.details ?? "",
                    author: decoded.author,
                    update: decoded.update ?? "",
                    createCompiled:
                        decoded.createCompiled
                            ?? true
                )
            )
        }

        return .object([
            "configuration": .string(result.configurationURL.path),
            "compiled": .string(result.compiledURL.path),
            "createdConfiguration": .bool(result.createdConfiguration),
            "createdCompiled": .bool(result.createdCompiled),
        ])
    }
}

extension SwiftBuildObjectModernizeTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            SwiftBuildObjectModernizeToolInput.self,
            from: input
        )
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )

        return .init(
            toolName: name,
            risk: risk,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths:
                decoded.backup == false
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
                decoded.backup == false
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
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftBuildObjectModernizeToolInput.self,
            from: input
        )
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let result = try BuildObjectLifecycle.modernize(
            at: execution.projectRoot,
            backup: decoded.backup ?? true
        )

        var fields: [String: JSONValue] = [
            "path": .string(result.configurationURL.path),
            "name": .string(result.name),
            "modernized": .bool(result.modernized),
        ]

        if let backup = result.backupURL {
            fields["backup"] = .string(backup.path)
        }

        return .object(fields)
    }
}

extension SwiftAppBundleTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            SwiftAppBundleToolInput.self,
            from: input
        )
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let appName =
            decoded.appName
                ?? decoded.target
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
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftAppBundleToolInput.self,
            from: input
        )
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let plist =
            try decoded.plist.map {
                try execution.projectFile(
                    $0
                )
            }
        let result = try await AppBundleCreation.create(
            .init(
                project: execution.projectRoot,
                appName: decoded.appName,
                target: decoded.target,
                configuration:
                    decoded.configuration == .debug
                        ? .debug
                        : .release,
                plist: plist,
                plistSymlink:
                    decoded.plistSymlink
                        ?? true,
                resourcesBundle:
                    decoded.resourcesBundle
            )
        )

        return .object([
            "app": .string(result.appDirectory.path),
            "buildDir": .string(result.buildDirectory.path),
            "appName": .string(result.appName),
            "target": .string(result.target),
        ])
    }
}

extension SwiftDeployTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            SwiftDeployToolInput.self,
            from: input
        )
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let resolved = try await targetedDeployResolution(
            decoded,
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
                "deploy \(decoded.configuration.rawValue) -> \(resolved.destination.path)",
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
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftDeployToolInput.self,
            from: input
        )
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let resolved = try await targetedDeployResolution(
            decoded,
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

        return try JSONToolBridge.encode(
            SwiftDeployToolOutput(
                configuration: decoded.configuration.rawValue,
                destination: resolved.destination.path,
                products: resolved.plan.selectedProductNames
            )
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

extension SwiftRunProductTool:
    WorkspaceTargetableTool
{
    public func preflight(
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        let decoded = try JSONToolBridge.decode(
            SwiftRunProductToolInput.self,
            from: input
        )
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
            decoded.product
        ) else {
            throw SwiftRunError.productNotFound(
                product: decoded.product,
                available: names
            )
        }

        let suffix =
            decoded.verbose
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
                "Run Swift executable product '\(decoded.product)' at the selected workspace location.",
            commandPreview:
                "swift run \(decoded.product)\(suffix)",
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
        input: JSONValue,
        context: AgentToolExecutionContext
    ) async throws -> JSONValue {
        let decoded = try JSONToolBridge.decode(
            SwiftRunProductToolInput.self,
            from: input
        )
        let execution = try SwiftWorkspaceExecution.resolve(
            context,
            toolName: name
        )
        let arguments =
            decoded.verbose
                ? [
                    "--verbose",
                ]
                : []
        let result = try await SwiftRun.run(
            .init(
                product: decoded.product,
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

        return try JSONToolBridge.encode(
            SwiftRunProductToolOutput(
                product: result.product,
                isSuccess: result.isSuccess,
                exitCode: result.exitCode,
                signal: result.signal,
                stdout: result.stdoutText,
                stderr: result.stderrText
            )
        )
    }
}
