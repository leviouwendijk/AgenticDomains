import Agentic
import AgenticConfiguration
import Foundation
import IO
import Mail

public extension Email {
    /// The most one message may attach in total. Base64 grows it by a third,
    /// which keeps the message under the 25 MB most providers accept.
    static let attachmentLimit = 18 * 1024 * 1024

    /// A file to attach, checked to exist and to lie where attachments may come from.
    struct AttachmentFile: Sendable, Hashable {
        public let url: URL
        public let bytes: Int

        public var description: String {
            "\(url.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)))"
        }
    }

    /// Where attachments may come from: the workspace, the exports directory
    /// of `settings.frame`, and the attachment downloads directory.
    static func attachmentRoots(
        in context: ToolContext
    ) -> [URL] {
        let workspace = context.workspace?.rootURL ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        var roots = [workspace]
        if let exports = try? AgentHomeLocator().resolveHome().settings().exports.resolvedDirectory(workspace: workspace.path) {
            roots.append(exports)
        }
        if let downloads = try? downloads(in: context) {
            roots.append(downloads)
        }
        return roots
    }

    /// `paths` as files: `~` expanded, relative to the workspace, symbolic links
    /// resolved, each inside an attachment root, and together within the limit.
    static func attachmentFiles(
        _ paths: [String]?,
        in context: ToolContext
    ) throws -> [AttachmentFile] {
        let paths = (paths ?? []).compactMap(nonEmpty)
        guard !paths.isEmpty else {
            return []
        }
        let roots = attachmentRoots(in: context).map { $0.resolvingSymlinksInPath().standardizedFileURL }
        let workspace = roots[0]

        var files: [AttachmentFile] = []
        for path in paths {
            let expanded = (path as NSString).expandingTildeInPath
            let url = (expanded.hasPrefix("/")
                ? URL(fileURLWithPath: expanded)
                : workspace.appendingPathComponent(expanded))
                .resolvingSymlinksInPath()
                .standardizedFileURL
            guard roots.contains(where: { url.path.hasPrefix($0.path.hasSuffix("/") ? $0.path : $0.path + "/") }) else {
                throw Failure.attachmentOutside(path, roots: roots.map(\.path))
            }
            let snapshot = try FileInspector(url).inspect(followingSymlinks: true)
            guard snapshot.existed, snapshot.kind == .file, let bytes = snapshot.byteCount else {
                throw Failure.attachmentMissing(path)
            }
            files.append(AttachmentFile(url: url, bytes: bytes))
        }
        let total = files.reduce(0) { $0 + $1.bytes }
        guard total <= attachmentLimit else {
            throw Failure.attachmentsTooLarge(bytes: total, limit: attachmentLimit)
        }
        return files
    }
}
