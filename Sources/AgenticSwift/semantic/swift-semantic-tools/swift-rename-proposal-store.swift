import Foundation
import Path
import SwiftSemantics
import Workspace

/// In-process, short-lived compiler proposal storage. A missing or expired
/// proposal fails closed; callers cannot supply their own WorkspaceEdit.
actor SwiftRenameProposalStore {
    static let shared = SwiftRenameProposalStore()

    struct Record: Sendable {
        let proposal: SwiftSemanticRenameResult
        let root: URL
        let rootIdentifier: PathAccessRootIdentifier
        let revision: WorkspaceRevision
        let sources: [URL: String]
        let expires: Date
    }

    enum Failure: Error, Sendable {
        case unavailable
        case contextMismatch
    }

    private var records: [UUID: Record] = [:]

    func retain(
        _ proposal: SwiftSemanticRenameResult,
        workspace: WorkspaceContext,
        sources: [URL: String]
    ) -> UUID {
        let now = Date()
        records = records.filter { $0.value.expires > now }
        // Keep this in-memory registry bounded without global persistence.
        if records.count >= 64 {
            records.removeAll()
        }
        let id = UUID()
        records[id] = Record(
            proposal: proposal,
            root: workspace.absoluteURL,
            rootIdentifier: workspace.rootIdentifier,
            revision: workspace.revision,
            sources: sources,
            expires: now.addingTimeInterval(900)
        )
        return id
    }

    func resolve(_ id: UUID, workspace: WorkspaceContext) throws -> Record {
        guard let record = records[id], record.expires > Date() else {
            records.removeValue(forKey: id)
            throw Failure.unavailable
        }
        guard record.root == workspace.absoluteURL,
            record.rootIdentifier == workspace.rootIdentifier,
            record.revision == workspace.revision else {
            throw Failure.contextMismatch
        }
        return record
    }
}
