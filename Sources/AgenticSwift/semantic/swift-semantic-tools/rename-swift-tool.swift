import Agentic
import AgenticIO
import Foundation
import Macros
import Primitives
import Schema
import SwiftRefactoring
import SwiftRefactoringWriters
import SwiftSemantics
import Workspace
import Writers
import Path

public struct SwiftRenamePreparedWork: Sendable, Codable, Hashable {
    public let input: SwiftLang.Tools.RenameSwift.Input
    public let rootURL: URL
    public let absoluteURL: URL
    public let rootIdentifier: PathAccessRootIdentifier
    public let revision: WorkspaceRevision
    public let files: [URL: String]
    public let plan: StandardMutationPlan
}

public enum SwiftRenamePreparedWorkSchema {
    public static let value = PreparedOperation.Schema(
        identifier: "tool.rename_swift",
        version: .init(major: 1, minor: 0, patch: 0)
    )
}

public enum SwiftRenameToolError: Error, Sendable {
    case unsupportedPackageContent(URL)
    case unsupportedDocumentVersion(URL)
    case unsupportedSource(URL)
    case contextMismatch
}

public extension SwiftLang.Tools {
    @Tool("rename_swift")
    struct RenameSwift {
        @JSONSchema
        public struct Input: Codable, Sendable, Hashable {
            /// Opaque handle returned by propose_swift_rename; arbitrary edits are not accepted.
            public let proposalID: UUID

            public init(proposalID: UUID) {
                self.proposalID = proposalID
            }
        }

        @JSONSchema
        public struct Output: Codable, Sendable, Hashable {
            public let planID: UUID
            public let resultID: UUID?
            public let submissionID: UUID?
            public let status: String
            public let changedFiles: Int
            public let failure: String?
        }

        public static let purpose =
            "Review a compiler-produced, source-bound multi-file Swift rename as a Writers diff; after approval, recheck source freshness and publish or stage the exact reviewed plan without requiring a SwiftPM build."
        public static let risk: ActionRisk = .privileged

        public init() {}

        public func prepare(
            _ input: Input,
            in context: ToolContext
        ) async throws -> CapabilityPreparation<ToolPreflight> {
            let workspace = try SwiftSemanticToolSupport.resolve(
                context.workspace,
                toolName: Self.definition.identifier.rawValue
            ).workspace
            let retained = try await SwiftRenameProposalStore.shared.resolve(
                input.proposalID,
                workspace: workspace
            )
            let writer = try WorkspaceWriter(
                root: workspace.absoluteURL,
                rootIdentifier: workspace.rootIdentifier
            )
            let package = try capturePackage(
                workspace: workspace,
                writer: writer
            )
            for (file, text) in retained.sources {
                guard package.files[file] == text else {
                    throw SwiftRefactoringError.staleSource(file)
                }
            }
            for document in retained.proposal.documents where document.version != nil {
                throw SwiftRenameToolError.unsupportedDocumentVersion(document.uri)
            }
            let rename = try SwiftRefactoringRenamePlanner().plan(
                retained.proposal,
                sources: package.files
            )
            let draft = try SwiftRefactoringWritersAdapter().prepareReview(
                rename,
                package: package,
                workspace: writer
            )

            let paths: [String] = try draft.mutationPlan.entries.map { entry in
                let authorized = try SwiftRefactoringWorkspaceSources.authorize(
                    entry.target,
                    packageRoot: workspace.absoluteURL,
                    in: writer
                )
                _ = try FileToolAccess.authorize(
                    workspace: workspace,
                    rootID: workspace.rootIdentifier,
                    path: authorized.absoluteURL.path,
                    capability: .write,
                    toolName: Self.definition.identifier.rawValue
                )
                return authorized.presentationPath
            }
            let readPaths: [String] = try package.files.keys.map { file in
                let authorized = try SwiftRefactoringWorkspaceSources.authorize(
                    file,
                    packageRoot: workspace.absoluteURL,
                    in: writer
                )
                _ = try FileToolAccess.authorize(
                    workspace: workspace,
                    rootID: workspace.rootIdentifier,
                    path: authorized.absoluteURL.path,
                    capability: .read,
                    toolName: Self.definition.identifier.rawValue
                )
                return authorized.presentationPath
            }
            let difference = try PreparedMutationDifferenceProjection.project(
                draft.mutationPlan,
                root: workspace.absoluteURL,
                presentationPaths: paths,
                title: "Swift semantic rename preview"
            )
            let review = ToolPreflight(
                tool: Self.definition.identifier,
                risk: Self.risk,
                summary: "Review a semantic rename affecting \(paths.count) file(s), then publish the approved Writers plan after freshness checks.",
                access: .init(
                    targets: Array(Set(paths + readPaths)).sorted(),
                    roots: [workspace.rootIdentifier.rawValue],
                    capabilities: [.read, .write]
                ),
                estimates: .init(
                    write: .init(count: draft.mutationPlan.entries.count),
                    runtime: 15
                ),
                preview: .init(difference: difference),
                sideEffects: [
                    "After approval and source-freshness checks, the reviewed changes will be published or staged through Writers. No package build is performed."
                ],
                policyChecks: [
                    "workspace_authorized",
                    "reviewed_writers_plan_retained",
                    "source_tree_scanned_and_authorized",
                    "source_freshness_required_after_approval"
                ],
                warnings: [
                    "Rename scope is limited to the authorized SwiftPM package source tree; the Sources/ scan does not prove a complete external reference graph. Compilation is not performed.",
                    "Versioned SourceKit documents require an authoritative document-version bridge; proposals are short-lived and bound to source snapshots."
                ]
            )
            let work = SwiftRenamePreparedWork(
                input: input,
                rootURL: workspace.rootURL,
                absoluteURL: workspace.absoluteURL,
                rootIdentifier: workspace.rootIdentifier,
                revision: workspace.revision,
                files: package.files,
                plan: draft.mutationPlan
            )
            return .init(
                review: review,
                operation: .init(
                    schema: SwiftRenamePreparedWorkSchema.value,
                    plan: try JSONValue.encoding(work)
                )
            )
        }

        public func preflight(
            _ input: Input,
            in context: ToolContext
        ) async throws -> ToolPreflight {
            try await prepare(input, in: context).review
        }

        public func call(
            _ input: Input,
            in context: ToolContext
        ) async throws -> Output {
            throw ToolPreparationError.prepared_operation_required
        }

        public func call(
            _ input: Input,
            prepared operation: PreparedOperation.Envelope?,
            in context: ToolContext
        ) async throws -> Output {
            guard let operation else {
                throw ToolPreparationError.prepared_operation_required
            }
            guard operation.schema == SwiftRenamePreparedWorkSchema.value else {
                throw PreparedOperation.EnvelopeError.schema_mismatch(
                    expected: SwiftRenamePreparedWorkSchema.value,
                    actual: operation.schema
                )
            }
            let work = try operation.plan.decode(SwiftRenamePreparedWork.self)
            let workspace = try SwiftSemanticToolSupport.resolve(
                context.workspace,
                toolName: Self.definition.identifier.rawValue
            ).workspace
            guard work.input == input,
                work.rootURL == workspace.rootURL,
                work.absoluteURL == workspace.absoluteURL,
                work.rootIdentifier == workspace.rootIdentifier,
                work.revision == workspace.revision else {
                throw SwiftRenameToolError.contextMismatch
            }
            let writer = try WorkspaceWriter(
                root: workspace.absoluteURL,
                rootIdentifier: workspace.rootIdentifier
            )
            for file in work.plan.entries.map(\.target) {
                let authorized = try SwiftRefactoringWorkspaceSources.authorize(
                    file,
                    packageRoot: workspace.absoluteURL,
                    in: writer
                )
                _ = try FileToolAccess.authorize(
                    workspace: workspace,
                    rootID: workspace.rootIdentifier,
                    path: authorized.absoluteURL.path,
                    capability: .write,
                    toolName: Self.definition.identifier.rawValue
                )
            }
            for file in work.files.keys {
                let authorized = try SwiftRefactoringWorkspaceSources.authorize(
                    file,
                    packageRoot: workspace.absoluteURL,
                    in: writer
                )
                _ = try FileToolAccess.authorize(
                    workspace: workspace,
                    rootID: workspace.rootIdentifier,
                    path: authorized.absoluteURL.path,
                    capability: .read,
                    toolName: Self.definition.identifier.rawValue
                )
            }
            let package = try SwiftRefactoringCompilerPackage(
                root: work.absoluteURL,
                files: work.files
            )
            let draft = SwiftRefactoringPublicationDraft(
                mutationPlan: work.plan,
                snapshot: .init(package: package)
            )
            // Compiler validation is optional, not a publication prerequisite.
            // Recheck the exact source snapshot before Writers publication.
            try draft.snapshot.requireCurrent(in: writer)
            let publication = try await PreparedWritersPublisher().publish(
                draft.mutationPlan,
                in: workspace,
                using: writer
            )
            switch publication {
            case .applied(let result):
                return .init(
                    planID: work.plan.id,
                    resultID: result.id,
                    submissionID: nil,
                    status: result.status.rawValue,
                    changedFiles: result.records.count,
                    failure: result.failed?.message
                )
            case .staged(let submissionID):
                return .init(
                    planID: work.plan.id,
                    resultID: nil,
                    submissionID: submissionID,
                    status: "staged",
                    changedFiles: work.plan.entries.count,
                    failure: nil
                )
            }
        }

        private func capturePackage(
            workspace: WorkspaceContext,
            writer: WorkspaceWriter
        ) throws -> SwiftRefactoringCompilerPackage {
            let toolName = Self.definition.identifier.rawValue
            _ = try FileToolAccess.authorize(
                workspace: workspace,
                rootID: workspace.rootIdentifier,
                path: ".",
                capability: .scan,
                toolName: toolName
            )
            _ = try FileToolAccess.authorize(
                workspace: workspace,
                rootID: workspace.rootIdentifier,
                path: "Package.swift",
                capability: .read,
                toolName: toolName
            )
            let result = try PathScan.scan(
                .init(includes: [
                    .init(pattern: .init(interpreting: "Sources", "**"))
                ]),
                relativeTo: .directoryURL(workspace.absoluteURL),
                configuration: .init(
                    includeHidden: true,
                    followSymlinks: false,
                    emitDirectories: false,
                    emitFiles: true
                )
            )
            guard result.warnings.isEmpty else {
                throw SwiftRenameToolError.unsupportedPackageContent(
                    workspace.absoluteURL.appendingPathComponent("Sources")
                )
            }
            let files = result.matches.map(\.url)
            for file in files {
                _ = try FileToolAccess.authorize(
                    workspace: workspace,
                    rootID: workspace.rootIdentifier,
                    path: file.path,
                    capability: .read,
                    toolName: toolName
                )
            }
            return try SwiftRefactoringWorkspaceSources().capture(
                sourceFiles: files,
                in: writer
            )
        }
    }
}
