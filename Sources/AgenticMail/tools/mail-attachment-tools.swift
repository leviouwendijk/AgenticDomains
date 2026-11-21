import Agentic
import Foundation
import IMAP
import Mail
import MailFrame
import Macros
import Schema

public extension Email.Tools {
    @Tool("save_attachment")
    struct SaveAttachment {
        @JSONSchema
        public struct Input: HashableSource {
            /// The account's name; the default account when absent.
            public let account: String?
            /// The mailbox holding the message; INBOX when absent.
            public let mailbox: String?
            /// The message's UID from mail_tool_search.
            public let uid: Int
            /// Which attachments, by filename as mail_tool_read lists them; all when absent.
            public let filenames: [String]?

            public init(account: String? = nil, mailbox: String? = nil, uid: Int, filenames: [String]? = nil) {
                self.account = account
                self.mailbox = mailbox
                self.uid = uid
                self.filenames = filenames
            }
        }

        @JSONSchema
        public struct SavedFile: HashableResult {
            /// The name in the message.
            public let filename: String
            /// Where it was written; a taken name gets ` (2)`, nothing is overwritten.
            public let path: String
            public let content_type: String
            public let bytes: Int
        }

        @JSONSchema
        public struct Output: HashableResult {
            /// The message's folder under the exports directory.
            public let directory: String
            public let saved: [SavedFile]
        }

        public static let purpose =
            "Save a message's attachments as files under the Agentic exports directory (mail/<account>/<mailbox>-<uid>/), for the owner or for tools that read files. Needs read access to the mailbox; never overwrites; does not mark the message read."
        public static let risk: ActionRisk = .boundedmutate

        public init() {}

        public func preflight(_ input: Input, in context: ToolContext) async throws -> ToolPreflight {
            let runtime = try Email.runtime(in: context)
            let account = try runtime.account(input.account)
            let mailbox = input.mailbox.flatMap(Email.nonEmpty) ?? "INBOX"
            let folder = Email.folder(for: account.identifier, mailbox: mailbox, uid: input.uid, in: try Email.downloads(in: context))
            let which = input.filenames.map { $0.joined(separator: ", ") } ?? "every attachment"
            return ToolPreflight(
                tool: Self.definition.identifier,
                risk: Self.definition.risk,
                summary: "Save \(which) of \(account.identifier):\(mailbox) UID \(input.uid) into \(folder.path)",
                access: .init(targets: [folder.path]),
                sideEffects: ["writes new files under \(folder.path); existing files are kept"]
            )
        }

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let authorization = try await Email.authorization(in: context)
            let runtime = authorization.runtime
            let account = try runtime.account(input.account)
            let mailbox = input.mailbox.flatMap(Email.nonEmpty) ?? "INBOX"
            try runtime.access.check(mailbox: mailbox)
            try authorization.require(.read, account: account)

            let message = try await runtime.imap(account).session { session in
                let role = try await Email.role(of: mailbox, account: account, authorization: authorization, session: session)
                try authorization.require(.read, account: account, mailbox: (mailbox, role))
                try await session.select(mailbox)
                return try await session.message(IMAPUID(UInt32(clamping: input.uid)))
            }
            guard let message else {
                throw Email.Failure.messageNotFound(uid: input.uid, mailbox: mailbox)
            }

            let available = message.attachments.map(\.filename)
            guard !available.isEmpty else {
                throw Email.Failure.noAttachments(uid: input.uid, mailbox: mailbox)
            }
            let wanted = (input.filenames ?? []).compactMap(Email.nonEmpty)
            for name in wanted where !available.contains(name) {
                throw Email.Failure.unknownAttachment(name, known: available)
            }

            let folder = Email.folder(for: account.identifier, mailbox: mailbox, uid: input.uid, in: try Email.downloads(in: context))
            var saved: [SavedFile] = []
            for (index, attachment) in message.attachments.enumerated() where wanted.isEmpty || wanted.contains(attachment.filename) {
                let url = try attachment.save(in: folder, index: index)
                saved.append(SavedFile(filename: attachment.filename, path: url.path, content_type: attachment.contentType, bytes: attachment.data.count))
            }
            return Output(directory: folder.path, saved: saved)
        }
    }
}
