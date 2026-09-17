import Agentic
import AgenticExecution
import Documentation
import Foundation

actor SwiftArchitectureRuntime {
    static let shared = SwiftArchitectureRuntime()

    private struct Key:
        Hashable
    {
        let root: URL
        let access: SwiftArchitectureAccessLevel
    }

    private var snapshots: [Key: DocumentationWorkspaceSnapshot] = [:]

    func snapshot(
        at root: URL,
        access: SwiftArchitectureAccessLevel,
        refresh: Bool
    ) async throws -> DocumentationWorkspaceSnapshot {
        let key = Key(
            root: root.standardizedFileURL,
            access: access
        )

        if !refresh,
           let existing = snapshots[key]
        {
            return existing
        }

        let derived = try await DocumentationWorkspace.snapshot(
            at: key.root,
            minimumAccessLevel: access.executable
        )

        snapshots[key] = derived
        return derived
    }
}

enum SwiftArchitectureToolSupport {
    static func localSnapshot(
        context: AgentToolExecutionContext,
        access: SwiftArchitectureAccessLevel?,
        refresh: Bool?,
        toolName: String
    ) async throws -> DocumentationWorkspaceSnapshot {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: toolName
        )

        return try await SwiftArchitectureRuntime.shared.snapshot(
            at: execution.projectRoot,
            access: access ?? .internal,
            refresh: refresh ?? false
        )
    }

    static func remoteSnapshot(
        input: InspectSwiftRepositoryArchitectureToolInput
    ) async throws -> DocumentationWorkspaceSnapshot {
        guard
            let origin = URL(
                string: input.origin
            ),
            origin.scheme != nil
        else {
            throw URLError(
                .badURL
            )
        }

        let revision: DocumentationRepositoryRevision

        switch input.revisionKind {
        case .branch:
            revision = .branch(
                input.revision
            )
        case .tag:
            revision = .tag(
                input.revision
            )
        case .commit:
            revision = .commit(
                input.revision
            )
        case .reference:
            revision = .reference(
                input.revision
            )
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "agentic-swift-architecture-\(UUID().uuidString)",
                isDirectory: true
            )

        defer {
            try? FileManager.default.removeItem(
                at: root
            )
        }

        let materialization = try await DocumentationRepositoryMaterializer.materialize(
            .init(
                origin: origin,
                revision: revision
            ),
            in: root
        )

        return try await DocumentationWorkspace.snapshot(
            at: materialization.checkoutRoot,
            minimumAccessLevel:
                (input.minimumAccessLevel ?? .internal).executable
        )
    }

    static func limit(
        _ requested: Int?,
        default defaultValue: Int = 200
    ) -> Int {
        min(
            5_000,
            max(
                1,
                requested ?? defaultValue
            )
        )
    }

    static func preflight(
        context: AgentToolExecutionContext,
        toolName: String,
        summary: String,
        remote: Bool = false
    ) throws -> ToolPreflight {
        let execution = try SwiftSemanticToolSupport.resolve(
            context,
            toolName: toolName
        )

        let sideEffects: [String]
        let warnings: [String]
        let policyCheck: String

        if remote {
            sideEffects = [
                "Clones and checks out the explicitly supplied Git repository revision into disposable temporary storage.",
                "SwiftPM symbol-graph generation may resolve dependencies and update .build state inside the disposable checkout.",
                "SwiftPM symbol-graph generation may execute package plugins or macros.",
            ]
            warnings = [
                "Remote repository inspection performs network and compiler execution before returning observational semantics.",
            ]
            policyCheck = "remote_repository_semantic_materialization_reviewed"
        } else {
            sideEffects = [
                "SwiftPM symbol-graph generation may resolve dependencies and update dependency, checkout, build, or index state under .build.",
                "SwiftPM symbol-graph generation may execute package plugins or macros.",
            ]
            warnings = [
                "Architecture inspection is observational at the semantic layer but compiler preparation is not guaranteed to be filesystem read-only.",
            ]
            policyCheck = "swift_symbol_graph_preparation_reviewed"
        }

        return .init(
            toolName: toolName,
            risk: .privileged,
            workspaceRoot: execution.workspace.rootURL.path,
            targetPaths: [
                execution.projectRoot.path,
            ],
            summary: summary,
            estimatedRuntimeSeconds: 120,
            sideEffects: sideEffects,
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                policyCheck,
            ],
            warnings: warnings
        )
    }
}
