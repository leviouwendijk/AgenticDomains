import Reporting
import Agentic
import Workspace
import Executable
import Interfaces
import Foundation
import Primitives
import Version

struct SwiftWorkspaceExecution {
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
                toolName: "swift_tool_app_bundle",
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
                toolName: "swift_tool_app_bundle",
                operation: "resolve project-relative file path",
                exitCode: nil,
                signal: nil,
                detail: "Resolved path escaped the selected Swift package root."
            )
        }

        return candidate
    }
}

extension SwiftLang.Tools.ExecutableProducts {
    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        _ = input
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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
            preview: .init([
                .command(.init("swift package dump-package")),
            ]),
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
        in context: ToolContext
    ) async throws -> Output {
        _ = input
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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

extension SwiftLang.Tools.PackageUpdate {
    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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
            preview: .init([
                .command(.init("swift package update")),
            ]),
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
        in context: ToolContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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

extension SwiftLang.Tools.Resolve {
    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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
            preview: .init([
                .command(.init("swift package resolve")),
            ]),
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
        in context: ToolContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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

extension SwiftLang.Tools.Clean {
    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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
            preview: .init([
                .command(.init("swift package clean")),
            ]),
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
        in context: ToolContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )

        try await Executable.Build.clean(
            at: execution.projectRoot
        )

        return Output(
            status: "passed"
        )
    }
}

extension SwiftLang.Tools.Version {
    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: "Inspect Swift project version state at the selected workspace location.",
            access: .init(
                targets: [
                    execution.projectPath(PackageFrame.fileName).path,
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
        in context: ToolContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )
        let package = try PackageFrame.package(in: execution.projectRoot) ?? PackageConfiguration()
        let status = try await PackageVersionStatus.inspect(
            at: execution.projectRoot,
            configuration: package
        )
        let divergence = try? await GitRepo.divergence(execution.projectRoot)

        return Output(
            release: status.release.map(ReleaseTag.name(for:)),
            commit: status.head?.commit,
            dirty: status.head?.dirty,
            deployed: status.deployed.map { entry in
                Deployed(
                    product: entry.product,
                    version: entry.metadata?.version.map(ReleaseTag.name(for:)),
                    commit: entry.metadata?.commit,
                    dirty: entry.metadata?.dirty
                )
            },
            outdated: status.behind,
            ahead: divergence?.ahead,
            behind: divergence?.behind
        )
    }
}

extension SwiftLang.Tools.IncrementVersion {
    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary:
                "Release the next \(input.level.rawValue) version: tag HEAD and push the tag.",
            access: .init(
                targets: [
                    execution.projectRoot.path
                ]
            ),
            sideEffects: [
                "Creates an annotated git tag on HEAD.",
                "Pushes the tag to the upstream remote.",
            ],
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "typed_release_tag",
            ]
        )
    }

    public func call(
        _ input: Input,
        in context: ToolContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )
        let result = try await GitRepo.release(
            .next(input.level),
            at: execution.projectRoot
        )

        return Output(
            before: result.from.map(ReleaseTag.name(for:)),
            after: ReleaseTag.name(for: result.to),
            level: input.level.rawValue
        )
    }
}

extension SwiftLang.Tools.KillSwiftPM {
    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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
            preview: .init([
                .command(.init(input.dryRun == true ? "kill-swiftpm --dry-run" : "kill-swiftpm")),
            ]),
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
        in context: ToolContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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

extension SwiftLang.Tools.BuildLibrary {
    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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
        in context: ToolContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )
        let configuration =
            input.configuration
                ?? .release
        let config = Executable.Build.Config(
            mode:
                configuration == .debug
                    ? .debug
                    : .release
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

extension SwiftLang.Tools.PackageFrameInit {
    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: "Write package.frame (and Tests/package.frame) at the selected workspace location.",
            access: .init(
                targets: [
                    execution.projectPath(PackageFrame.fileName).path,
                    execution.projectPath("\(Tests.conventionalDirectory)/\(PackageFrame.fileName)").path,
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
                "typed_package_frame_initialization",
            ]
        )
    }

    public func call(
        _ input: Input,
        in context: ToolContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )
        let initialized = try PackageFrame.initialize(in: execution.projectRoot)

        return Output(
            package: initialized.package?.path,
            tests: initialized.tests?.path
        )
    }
}

extension SwiftLang.Tools.AppBundle {
    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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
        in context: ToolContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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

extension SwiftLang.Tools.Deploy {
    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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
            preview: .init([
                .report(
                    try ReportDocument(title: "Deploy", datasets: [], blocks: [
                        .facts(.init(facts: [
                            .init("configuration", input.configuration.rawValue),
                            .init("destination", resolved.destination.path),
                        ])),
                    ])
                ),
            ]),
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
        in context: ToolContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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
                resolved.plan.perProductDestinations,
            identity: await Self.builtIdentity(
                project: execution.projectRoot,
                mode: resolved.plan.request.config.mode,
                products: resolved.plan.selectedProductNames
            )
        )

        return Output(
                configuration: input.configuration.rawValue,
                destination: resolved.destination.path,
                products: resolved.plan.selectedProductNames
            )
    }

    /// What the products were built from: their build record in .build/<mode>/, or HEAD when
    /// no build recorded them (then the deployed metadata may be newer than the binary).
    private static func builtIdentity(
        project: URL,
        mode: Executable.Build.Config.Mode,
        products: [String]
    ) async -> BuildIdentity? {
        let records = BuildRecord.directory(project: project, mode: mode)
        for product in products {
            if let metadata = (try? ProductMetadata.read(product: product, in: records)) ?? nil,
               let commit = metadata.commit {
                return BuildIdentity(version: metadata.version, commit: commit, dirty: metadata.dirty)
            }
        }
        return await BuildIdentity.current(at: project)
    }

    private func targetedDeployResolution(
        _ input: Input,
        project: URL
    ) async throws -> (
        destination: URL,
        plan: Executable.Build.Plan
    ) {
        let mode: Executable.Build.Config.Mode =
            switch input.configuration {
            case .debug:
                .debug

            case .release:
                .release
            }
        let destination =
            Executable.Build.defaultDeploymentDirectory
        let request = Executable.Build.Request(
            project: project,
            config: .init(
                mode: mode
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
            try await Executable.Build.resolve(
                request
            )
        )
    }
}

extension SwiftLang.Tools.RunProduct {
    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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
            preview: .init([
                .command(.init("swift run \(input.product)\(suffix)")),
            ]),
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
        in context: ToolContext
    ) async throws -> Output {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
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
                detail: [
                    "stdout (tail):",
                    String(result.stdoutText.suffix(12_288)),
                    "stderr (tail):",
                    String(result.stderrText.suffix(4_096))
                ].joined(separator: "\n")
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


extension SwiftLang.Tools.PackageUpdate {
    public func process(
        _ output: Output,
        input _: Input
    ) -> ToolExecution.Projection? {
        output.projection
    }
}

extension SwiftLang.Tools.Resolve {
    public func process(
        _ output: Output,
        input _: Input
    ) -> ToolExecution.Projection? {
        output.projection
    }
}

extension SwiftLang.Tools.Deploy {
    public func process(
        _ output: Output,
        input _: Input
    ) -> ToolExecution.Projection? {
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

extension SwiftLang.Tools.RunProduct {
    public func process(
        _ output: Output,
        input _: Input
    ) -> ToolExecution.Projection? {
        var facts: [ToolExecution.Projection.Fact] = [
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
