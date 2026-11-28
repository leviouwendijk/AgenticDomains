import Agentic
import AgenticConfiguration
import Foundation

public extension Email {
    /// Where saved attachments go. A host may insert one; otherwise `mail/`
    /// under the exports directory of `settings.frame`, which defaults to
    /// `.agentic/artifacts/exports` in the workspace.
    struct Downloads: Sendable {
        public let directory: URL

        public init(
            directory: URL
        ) {
            self.directory = directory.standardizedFileURL
        }
    }

    static func downloads(
        in context: CapabilityContext
    ) throws -> URL {
        if let downloads = try? context.require(Downloads.self) {
            return downloads.directory
        }
        let workspace = context.workspace?.rootURL.path ?? FileManager.default.currentDirectoryPath
        return try AgentHomeLocator()
            .resolveHome()
            .settings()
            .exports
            .resolvedDirectory(workspace: workspace)
            .appendingPathComponent("mail", isDirectory: true)
    }

    /// One folder per message: `<account>/<mailbox>-<uid>`, the mailbox flattened to one component.
    static func folder(
        for account: String,
        mailbox: String,
        uid: Int,
        in directory: URL
    ) -> URL {
        let flat = mailbox
            .replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return directory
            .appendingPathComponent(account, isDirectory: true)
            .appendingPathComponent("\(flat.isEmpty ? "mailbox" : flat)-\(uid)", isDirectory: true)
    }
}
