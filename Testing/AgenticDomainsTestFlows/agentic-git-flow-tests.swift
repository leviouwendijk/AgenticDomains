import Agentic
import AgenticGit
import AgenticWorkspace
import AgenticExecution
import Foundation
import Interfaces
import Primitives
import TestFlows

extension AgenticDomainsFlowTesting {
    static func runAgenticGitToolSurface() async throws -> [TestFlowDiagnostic] {
        var registry = ToolRegistry()

        try registry.register(
            AgenticGitToolSet()
        )

        try Expect.equal(
            registry.count,
            14,
            "AgenticGit registered tool count after isolation and integration expansion"
        )

        let names = Set(
            registry.definitions.map(\.name)
        )

        for name in [
            "git_repository_state",
            "git_diff",
            "git_worktree_list",
            "git_worktree_create",
            "git_worktree_remove",
            "git_integration_plan",
            "git_integration_prepare",
            "git_integration_promote",
            "git_integration_cleanup",
            "git_reconciliation_plan",
            "git_pull",
            "git_prepare_commit",
            "git_commit_prepared",
            "git_push",
        ] {
            try Expect.true(
                names.contains(name),
                "AgenticGit registers \(name)"
            )
        }

        let missingSemanticSchemas =
            registry.capabilities
                .filter {
                    $0.semanticInputSchema == nil
                }
                .map(\.definition.name)
                .sorted()

        try Expect.equal(
            missingSemanticSchemas,
            [String](),
            "AgenticGit registered tools all project semantic input schemas"
        )

        return [
            .field(
                "registered",
                "\(registry.count)"
            ),
        ]
    }

    static func runAgenticGitWorktreeLifecycle() async throws -> [TestFlowDiagnostic] {
        let fixture = try await AgenticGitFlowFixture.make(
            "worktree-lifecycle"
        )

        defer {
            fixture.remove()
        }

        let create = GitWorktreeCreateTool()
        let createInput = GitWorktreeCreateToolInput(
                semanticKey: "agentic domains worktree fixture",
                baseRef: "master"
            )

        let createPreflight = try await create.preflight(
            createInput,
            context: .init(
                workspace: fixture.workspace
            )
        )

        try Expect.equal(
            createPreflight.risk,
            .boundedmutate,
            "git_worktree_create risk"
        )

        let createOutput = try await create.call(
            createInput,
            context: .init(
                workspace: fixture.workspace
            )
        )

        let worktree = createOutput.result.worktree

        try Expect.true(
            FileManager.default.fileExists(
                atPath: worktree.path.path
            ),
            "git_worktree_create materializes managed worktree"
        )

        try Expect.equal(
            worktree.branch,
            createOutput.branch,
            "created worktree owns semantic branch"
        )

        let list = GitWorktreeListTool()
        let listed = try await list.call(
            AgenticGitEmptyToolInput(),
            context: .init(
                workspace: fixture.workspace
            )
        )

        try Expect.true(
            listed.contains {
                $0.path == worktree.path
                    && $0.branch == createOutput.branch
            },
            "git_worktree_list exposes created worktree"
        )

        let remove = GitWorktreeRemoveTool()
        let removeInput = GitWorktreeRemoveToolInput(
                path: worktree.path.path
            )

        let removePreflight = try await remove.preflight(
            removeInput,
            context: .init(
                workspace: fixture.workspace
            )
        )

        try Expect.equal(
            removePreflight.risk,
            .boundedmutate,
            "git_worktree_remove risk"
        )

        let removed = try await remove.call(
            removeInput,
            context: .init(
                workspace: fixture.workspace
            )
        )

        try Expect.equal(
            removed.preservedBranch,
            createOutput.branch,
            "worktree removal explicitly preserves branch"
        )

        try Expect.true(
            !FileManager.default.fileExists(
                atPath: worktree.path.path
            ),
            "removed task worktree directory is gone"
        )

        try Expect.true(
            try await fixture.branchExists(
                createOutput.branch
            ),
            "task branch remains durable after worktree removal"
        )

        return [
            .field(
                "branch",
                createOutput.branch
            ),
            .field(
                "worktree",
                worktree.path.path
            ),
        ]
    }

    static func runAgenticGitIntegrationPreparation() async throws -> [TestFlowDiagnostic] {
        let fixture = try await AgenticGitFlowFixture.make(
            "integration-preparation"
        )

        defer {
            fixture.remove()
        }

        let create = GitWorktreeCreateTool()
        let source = try await create.call(
            GitWorktreeCreateToolInput(
                        semanticKey: "agentic domains integration source",
                        baseRef: "master"
                    ),
            context: .init(
                workspace: fixture.workspace
            )
        )

        let sourcePath = source.result.worktree.path

        try fixture.write(
            "source\n",
            path: "source.txt",
            at: sourcePath
        )
        try await fixture.commit(
            "source",
            paths: ["source.txt"],
            at: sourcePath
        )

        try fixture.write(
            "target\n",
            path: "target.txt",
            at: fixture.root
        )
        try await fixture.commit(
            "target",
            paths: ["target.txt"],
            at: fixture.root
        )

        let targetBefore = try await fixture.head()
        let planTool = GitIntegrationPlanTool()
        let planInput = GitIntegrationPlanToolInput(
                sourceRef: source.branch,
                targetRef: "master"
            )
        let planPreflight = try await planTool.preflight(
            planInput,
            context: .init(
                workspace: fixture.workspace
            )
        )

        try Expect.equal(
            planPreflight.risk,
            .observe,
            "git_integration_plan risk"
        )

        let planned = try await planTool.call(
            planInput,
            context: .init(
                workspace: fixture.workspace
            )
        )

        try Expect.equal(
            planned.plan.classification,
            .cleanMerge,
            "integration adapter retains clean-merge classification"
        )

        let prepare = GitIntegrationPrepareTool()
        let prepareInput = GitIntegrationPrepareToolInput(
                planReceipt: planned.receipt,
                semanticKey: "agentic domains integration prepare"
            )
        let preparePreflight = try await prepare.preflight(
            prepareInput,
            context: .init(
                workspace: fixture.workspace
            )
        )

        try Expect.equal(
            preparePreflight.risk,
            .boundedmutate,
            "git_integration_prepare risk"
        )

        let prepared = try await prepare.call(
            prepareInput,
            context: .init(
                workspace: fixture.workspace
            )
        )

        try Expect.equal(
            prepared.execution.status,
            .ready,
            "clean integration prepares as ready"
        )
        try Expect.equal(
            try await fixture.head(),
            targetBefore,
            "preparation leaves canonical master unchanged"
        )

        guard let integrationPath = prepared.execution.worktree else {
            try Expect.true(
                false,
                "prepared integration must expose disposable worktree"
            )
            return []
        }

        try Expect.equal(
            try fixture.read(
                "source.txt",
                at: integrationPath
            ),
            "source\n",
            "prepared integration contains source change"
        )
        try Expect.equal(
            try fixture.read(
                "target.txt",
                at: integrationPath
            ),
            "target\n",
            "prepared integration contains target change"
        )

        try await GitManagerIntegrationExecutor.cleanup(
            prepared.execution,
            discard: true,
            at: fixture.root
        )

        let remove = GitWorktreeRemoveTool()
        _ = try await remove.call(
            GitWorktreeRemoveToolInput(
                    path: sourcePath.path
                ),
            context: .init(
                workspace: fixture.workspace
            )
        )

        return [
            .field(
                "classification",
                planned.plan.classification.rawValue
            ),
            .field(
                "status",
                prepared.execution.status.rawValue
            ),
        ]
    }

    static func runAgenticGitIntegrationPromotionAndCleanup() async throws -> [TestFlowDiagnostic] {
        try await proveAgenticGitPromotionAndSafeCleanup()
        try await proveAgenticGitConflictDiscardGate()

        return [
            .field(
                "cases",
                "2"
            ),
        ]
    }
}

private func proveAgenticGitPromotionAndSafeCleanup() async throws {
    let fixture = try await AgenticGitFlowFixture.make(
        "integration-promotion"
    )

    defer {
        fixture.remove()
    }

    let create = GitWorktreeCreateTool()
    let source = try await create.call(
        GitWorktreeCreateToolInput(
                    semanticKey: "agentic domains promotion source",
                    baseRef: "master"
                ),
        context: .init(
            workspace: fixture.workspace
        )
    )

    let sourcePath = source.result.worktree.path

    try fixture.write(
        "source\n",
        path: "source.txt",
        at: sourcePath
    )
    try await fixture.commit(
        "source",
        paths: ["source.txt"],
        at: sourcePath
    )

    try fixture.write(
        "target\n",
        path: "target.txt",
        at: fixture.root
    )
    try await fixture.commit(
        "target",
        paths: ["target.txt"],
        at: fixture.root
    )

    let targetBefore = try await fixture.head()
    let planTool = GitIntegrationPlanTool()
    let planned = try await planTool.call(
        GitIntegrationPlanToolInput(
                    sourceRef: source.branch,
                    targetRef: "master"
                ),
        context: .init(
            workspace: fixture.workspace
        )
    )

    let prepare = GitIntegrationPrepareTool()
    let prepared = try await prepare.call(
        GitIntegrationPrepareToolInput(
                    planReceipt: planned.receipt,
                    semanticKey: "agentic domains promotion integration"
                ),
        context: .init(
            workspace: fixture.workspace
        )
    )

    let promote = GitIntegrationPromoteTool()
    let promoteInput = GitIntegrationPromoteToolInput(
            executionReceipt: prepared.receipt,
            targetBranch: "master"
        )
    let promotePreflight = try await promote.preflight(
        promoteInput,
        context: .init(
            workspace: fixture.workspace
        )
    )

    try Expect.equal(
        promotePreflight.risk,
        .privileged,
        "git_integration_promote risk"
    )

    let promotion = try await promote.call(
        promoteInput,
        context: .init(
            workspace: fixture.workspace
        )
    )

    try Expect.equal(
        promotion.previousTargetHead,
        targetBefore,
        "promotion receipt retains exact target pre-state"
    )
    try Expect.equal(
        try await fixture.head(),
        promotion.newTargetHead,
        "promotion advances master to prepared integration head"
    )
    try Expect.equal(
        try fixture.read(
            "source.txt",
            at: fixture.root
        ),
        "source\n",
        "promoted master contains source change"
    )

    let cleanup = GitIntegrationCleanupTool()
    let cleanupInput = GitIntegrationCleanupToolInput(
            executionReceipt: prepared.receipt
        )
    let cleanupPreflight = try await cleanup.preflight(
        cleanupInput,
        context: .init(
            workspace: fixture.workspace
        )
    )

    try Expect.equal(
        cleanupPreflight.risk,
        .privileged,
        "git_integration_cleanup risk"
    )

    _ = try await cleanup.call(
        cleanupInput,
        context: .init(
            workspace: fixture.workspace
        )
    )

    if let integrationPath = prepared.execution.worktree {
        try Expect.true(
            !FileManager.default.fileExists(
                atPath: integrationPath.path
            ),
            "safe cleanup removes disposable integration worktree"
        )
    }

    try Expect.true(
        try await fixture.branchExists(
            source.branch
        ),
        "safe cleanup preserves source branch"
    )

    let remove = GitWorktreeRemoveTool()
    _ = try await remove.call(
        GitWorktreeRemoveToolInput(
                path: sourcePath.path
            ),
        context: .init(
            workspace: fixture.workspace
        )
    )
}

private func proveAgenticGitConflictDiscardGate() async throws {
    let fixture = try await AgenticGitFlowFixture.make(
        "integration-conflict-cleanup"
    )

    defer {
        fixture.remove()
    }

    let create = GitWorktreeCreateTool()
    let source = try await create.call(
        GitWorktreeCreateToolInput(
                    semanticKey: "agentic domains conflict source",
                    baseRef: "master"
                ),
        context: .init(
            workspace: fixture.workspace
        )
    )

    let sourcePath = source.result.worktree.path

    try fixture.write(
        "source\n",
        path: "shared.txt",
        at: sourcePath
    )
    try await fixture.commit(
        "source conflict",
        paths: ["shared.txt"],
        at: sourcePath
    )

    try fixture.write(
        "target\n",
        path: "shared.txt",
        at: fixture.root
    )
    try await fixture.commit(
        "target conflict",
        paths: ["shared.txt"],
        at: fixture.root
    )

    let targetBefore = try await fixture.head()
    let planTool = GitIntegrationPlanTool()
    let planned = try await planTool.call(
        GitIntegrationPlanToolInput(
                    sourceRef: source.branch,
                    targetRef: "master"
                ),
        context: .init(
            workspace: fixture.workspace
        )
    )

    try Expect.equal(
        planned.plan.classification,
        .conflicts,
        "conflict adapter plan reports conflicts"
    )

    let prepare = GitIntegrationPrepareTool()
    let prepared = try await prepare.call(
        GitIntegrationPrepareToolInput(
                    planReceipt: planned.receipt,
                    semanticKey: "agentic domains conflict integration"
                ),
        context: .init(
            workspace: fixture.workspace
        )
    )

    try Expect.equal(
        prepared.execution.status,
        .conflicts,
        "conflict preparation remains isolated"
    )

    let cleanup = GitIntegrationCleanupTool()
    let safeInput = GitIntegrationCleanupToolInput(
            executionReceipt: prepared.receipt
        )

    var refused = false

    do {
        _ = try await cleanup.call(
            safeInput,
            context: .init(
                workspace: fixture.workspace
            )
        )
    } catch let error as GitManagerIntegrationExecutionError {
        if error == .cleanupRequiresDiscard {
            refused = true
        } else {
            throw error
        }
    }

    try Expect.true(
        refused,
        "conflicted integration cleanup requires explicit discard"
    )

    _ = try await cleanup.call(
        GitIntegrationCleanupToolInput(
                executionReceipt: prepared.receipt,
                discard: true
            ),
        context: .init(
            workspace: fixture.workspace
        )
    )

    try Expect.equal(
        try await fixture.head(),
        targetBefore,
        "discarding conflicted integration leaves master unchanged"
    )
    try Expect.true(
        try await fixture.branchExists(
            source.branch
        ),
        "discarding conflicted integration preserves source branch"
    )

    let remove = GitWorktreeRemoveTool()
    _ = try await remove.call(
        GitWorktreeRemoveToolInput(
                path: sourcePath.path
            ),
        context: .init(
            workspace: fixture.workspace
        )
    )
}

struct AgenticGitFlowFixture {
    let root: URL
    let workspace: AgentWorkspace

    static func make(
        _ name: String
    ) async throws -> Self {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "agentic-domains-git-\(name)-\(UUID().uuidString)",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        let fixture = try Self(
            root: root,
            workspace: AgentWorkspace(
                root: root
            )
        )

        _ = try await fixture.git([
            "init",
            "-q",
            "-b",
            "master",
        ])

        _ = try await fixture.git([
            "config",
            "user.email",
            "agentic@example.invalid",
        ])

        _ = try await fixture.git([
            "config",
            "user.name",
            "Agentic Test",
        ])

        try fixture.write(
            "base\n",
            path: "base.txt",
            at: root
        )

        try await fixture.commit(
            "base",
            paths: ["base.txt"],
            at: root
        )

        return fixture
    }

    func write(
        _ content: String,
        path: String,
        at directory: URL
    ) throws {
        try content.write(
            to: directory.appendingPathComponent(path),
            atomically: true,
            encoding: .utf8
        )
    }

    func read(
        _ path: String,
        at directory: URL
    ) throws -> String {
        try String(
            contentsOf: directory.appendingPathComponent(path),
            encoding: .utf8
        )
    }

    func commit(
        _ message: String,
        paths: [String],
        at directory: URL
    ) async throws {
        _ = try await git(
            ["add"] + paths,
            at: directory
        )
        _ = try await git(
            [
                "commit",
                "-q",
                "-m",
                message,
            ],
            at: directory
        )
    }

    func head(
        at directory: URL? = nil
    ) async throws -> String {
        try await git(
            [
                "rev-parse",
                "HEAD",
            ],
            at: directory ?? root
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    func branchExists(
        _ branch: String
    ) async throws -> Bool {
        let result = try await GitRepo.git(
            root,
            [
                "show-ref",
                "--verify",
                "--quiet",
                "refs/heads/\(branch)",
            ]
        )

        switch result.code {
        case 0:
            return true
        case 1:
            return false
        default:
            throw GitManagerError.unsafeSync(
                result.err
            )
        }
    }

    func git(
        _ arguments: [String],
        at directory: URL? = nil
    ) async throws -> String {
        let result = try await GitRepo.git(
            directory ?? root,
            arguments
        )

        guard result.code == 0 else {
            throw GitManagerError.unsafeSync(
                result.err.isEmpty
                    ? result.out
                    : result.err
            )
        }

        return result.out
    }

    func remove() {
        try? FileManager.default.removeItem(
            at: root
        )
    }
}
