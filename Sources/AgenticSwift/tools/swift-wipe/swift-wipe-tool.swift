import Agentic
import Workspace
import Executable
import Foundation
import Primitives
import Schema
import Macros

/// Delete SwiftPM build caches in the workspace, as `sbm wipe` does.
public extension SwiftLang.Tools {
    @Tool("wipe")
    struct WipeCaches {
        @JSONSchema
        public struct Input:
            Sendable,
            Codable,
            Hashable
        {
            /// Which packages: all (the package with its Tests/ and Benchmarks/), main (the
            /// package only) or extra (Tests/ and Benchmarks/ only).
            public enum Scope:
                String,
                Sendable,
                Codable,
                Hashable,
                CaseIterable,
                JSONSchemaProviding
            {
                case all
                case main
                case extra

                public static var jsonschema: JSONSchema {
                    .string(
                        cases: allCases.map(\.rawValue)
                    )
                }
            }

            /// Defaults to all.
            public let scope: Scope?
            /// Every package below the workspace root, at any depth (limit with depth).
            public let recursive: Bool?
            /// With recursive: how deep to search (the workspace root is 0).
            public let depth: Int?
            /// List what would be deleted, with sizes, without deleting.
            public let dryRun: Bool?
            /// Delete caches the keep list protects too.
            public let ignoreKeep: Bool?

            public init(
                scope: Scope? = nil,
                recursive: Bool? = nil,
                depth: Int? = nil,
                dryRun: Bool? = nil,
                ignoreKeep: Bool? = nil
            ) {
                self.scope = scope
                self.recursive = recursive
                self.depth = depth
                self.dryRun = dryRun
                self.ignoreKeep = ignoreKeep
            }
        }

        @JSONSchema
        public struct Output:
            Sendable,
            Codable,
            Hashable
        {
            /// False when a deletion failed.
            public let isSuccess: Bool
            public let dryRun: Bool
            public let packages: Int
            public let deleted: Int
            public let kept: Int
            public let skipped: Int
            public let failed: Int
            /// Bytes the planned deletions measured (dry run), or the volume's gain in available
            /// space (a real run); nil when unknown.
            public let bytes: Int64?
            /// Per directory: deleted, kept (keep list), skipped (build running) or failed.
            public let report: String

            public init(
                isSuccess: Bool,
                dryRun: Bool,
                packages: Int,
                deleted: Int,
                kept: Int,
                skipped: Int,
                failed: Int,
                bytes: Int64?,
                report: String
            ) {
                self.isSuccess = isSuccess
                self.dryRun = dryRun
                self.packages = packages
                self.deleted = deleted
                self.kept = kept
                self.skipped = skipped
                self.failed = failed
                self.bytes = bytes
                self.report = report
            }
        }

        public static let purpose = """
        Delete .build and .index-build of the workspace's Swift package through Executable's Wipe, the same plan `sbm wipe [all|main|extra] [-r] [-n]` makes: scope all (default) also covers Tests/ and Benchmarks/, main only the package, extra only Tests/ and Benchmarks/; recursive covers every package below the workspace root. The keep list (`sbm keep`) applies unless ignoreKeep, and caches of a running build are skipped. Use dryRun first to see what would go and how much it frees. SwiftPM's global cache is out of reach. To wipe around a build or test run, use their wipe/wipeBefore flags instead.
        """

        public static let risk: ActionRisk = .privileged

        public init() {}
    }
}

extension SwiftLang.Tools.WipeCaches {
    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        let execution = try SwiftWorkspaceExecution.resolve(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )
        let plan = try Self.plan(input, root: execution.projectRoot, measure: true)
        let dryRun = input.dryRun == true
        let size = ByteCountFormatter.string(fromByteCount: plan.measuredTotal, countStyle: .file)

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: dryRun
                ? "List the \(plan.deletions.count) cache directories a wipe would delete (\(size)) in \(plan.packages.count) package(s)."
                : "Delete \(plan.deletions.count) cache directories (\(size)) in \(plan.packages.count) package(s).",
            access: .init(
                targets: plan.deletions.map(\.directory.path)
            ),
            estimates: .init(
                write: .init(
                    count: dryRun ? 0 : plan.deletions.count
                )
            ),
            preview: .init([
                .command(.init(Self.command(input))),
            ]),
            sideEffects: dryRun ? [] : [
                "Deletes the listed .build and .index-build directories; the next build starts from scratch.",
            ],
            policyChecks: [
                "workspace_required",
                "workspace_location_selected",
                "typed_wipe_plan",
                ignoreKeepCheck(input),
                "running_builds_skipped",
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
        let dryRun = input.dryRun == true
        let plan = try Self.plan(input, root: execution.projectRoot, measure: dryRun)
        let buffer = TextBuffer(limit: 16_384)
        let summary = await Executable.Wipe.execute(plan, dryRun: dryRun, output: buffer.sink)

        return Output(
            isSuccess: summary.failed == 0,
            dryRun: dryRun,
            packages: summary.packages,
            deleted: summary.deleted,
            kept: summary.kept,
            skipped: summary.skipped,
            failed: summary.failed,
            bytes: dryRun ? plan.measuredTotal : summary.freed,
            report: SwiftTidySteps.report(buffer)
        )
    }

    public func process(
        _ output: Output,
        input _: Input
    ) -> ToolExecution.Projection? {
        let size = output.bytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "unknown"
        return .init(
            status: output.isSuccess ? "passed" : "failed",
            summary: output.dryRun
                ? "Dry run over \(output.packages) package(s): \(size) would be freed."
                : "\(output.deleted) deleted, \(output.kept) kept, \(output.skipped) skipped, \(output.failed) failed; freed \(size).",
            facts: [
                .init(label: "packages", value: "\(output.packages)"),
                .init(label: output.dryRun ? "would free" : "freed", value: size),
            ]
        )
    }

    private static func plan(
        _ input: Input,
        root: URL,
        measure: Bool
    ) throws -> Executable.Wipe.Plan {
        try Executable.Wipe.plan(
            .init(
                root: root,
                scope: Executable.Wipe.Scope(rawValue: (input.scope ?? .all).rawValue) ?? .all,
                recursive: input.recursive == true,
                depth: input.recursive == true ? input.depth : nil,
                ignoreKeep: input.ignoreKeep == true,
                measure: measure
            ),
            keep: KeepList.load()
        )
    }

    private static func command(
        _ input: Input
    ) -> String {
        var parts = ["sbm", "wipe", (input.scope ?? .all).rawValue]
        if input.recursive == true {
            parts.append("-r")
            if let depth = input.depth {
                parts.append(contentsOf: ["-d", "\(depth)"])
            }
        }
        if input.dryRun == true {
            parts.append("-n")
        } else {
            parts.append("-y")
        }
        if input.ignoreKeep == true {
            parts.append("--ignore-keep")
        }
        return parts.joined(separator: " ")
    }

    private func ignoreKeepCheck(
        _ input: Input
    ) -> String {
        input.ignoreKeep == true ? "keep_list_ignored" : "keep_list_applied"
    }
}
