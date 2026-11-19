import Agentic
import Foundation
import IMAP
import Mail
import MailFrame
import Macros
import Schema

public extension Email.Tools {
    @Tool("mail_draft")
    struct SaveDraft {
        public typealias Input = Email.Composition

        @JSONSchema
        public struct Output: HashableResult {
            public let account: String
            /// The folder the draft was saved in.
            public let folder: String
            /// The draft's UID there, when the server reports it.
            public let uid: Int?
            public let from: String
            public let to: [String]
            public let cc: [String]
            public let subject: String
        }

        public static let purpose =
            "Compose a message (or a reply to a UID) from an account's identity, as text and/or HTML with file attachments, signed, and save it in the account's Drafts folder for the owner to review and send. Sends nothing."
        public static let risk: ActionRisk = .boundedmutate

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let authorization = try await Email.authorization(in: context)
            let runtime = authorization.runtime
            let composed = try await Email.compose(input, with: authorization, in: context)
            let data = MailRenderer(keepsBcc: true).data(composed.message)

            let (folder, uid) = try await runtime.imap(composed.account).session { session in
                let folder = try await Email.folder(.drafts, for: composed.account, in: session, fallback: "Drafts") ?? "Drafts"
                let uid = try await session.append(data, to: folder, flags: [.draft, .seen])
                return (folder, uid)
            }

            return Output(
                account: composed.account.identifier,
                folder: folder,
                uid: uid.map { Int($0.rawValue) },
                from: Email.display(composed.message.from),
                to: composed.message.to.map(Email.display),
                cc: composed.message.cc.map(Email.display),
                subject: composed.message.subject
            )
        }
    }

    @Tool("mail_send")
    struct Send {
        public typealias Input = Email.Composition

        @JSONSchema
        public struct Output: HashableResult {
            public let account: String
            public let from: String
            public let accepted: [String]
            /// Recipients the server refused, with its reason.
            public let rejected: [String]
            /// Where a copy was saved, when the account has a Sent folder.
            public let sent_copy: String?
            public let warnings: [String]
        }

        public static let purpose =
            "Send a message (or a reply to a UID) from an account's identity, as text and/or HTML with file attachments, signed, and save a copy in Sent. The owner approves each message, unless the account allows sending and this session holds a draft grant on it; refused under the drafts policy."
        public static let risk: ActionRisk = .privileged

        public init() {}

        /// The account's policy decides the risk: drafts forbids, confirm needs review, allowed is bounded.
        public func preflight(_ input: Input, in context: ToolContext) async throws -> ToolPreflight {
            let authorization = try await Email.authorization(in: context)
            let runtime = authorization.runtime
            let account = try runtime.account(input.account)
            let identity = try Email.identity(input.from, in: account, access: runtime.access)
            let granted = authorization.level(account: account) == .draft
            let recipients = try (Email.addresses(input.to) + Email.addresses(input.cc) + Email.addresses(input.bcc))
                .map(\.address.raw)

            // The owner approves each message; only a draft grant on an account
            // that allows sending removes that step. Drafts-only never sends.
            let policy = runtime.access.sending(for: account)
            let risk: ActionRisk
            switch policy {
            case .drafts:
                risk = .forbidden
            case .confirm:
                risk = .privileged
            case .allowed:
                risk = granted ? .boundedmutate : .privileged
            }

            let subject = input.subject.flatMap(Email.nonEmpty)
                ?? input.reply_to_uid.map { "reply to UID \($0)" }
                ?? "(no subject)"
            let files = try Email.attachmentFiles(input.attachments, in: context)
            let text = input.body.flatMap(Email.nonEmpty) ?? input.html.map(ReceivedMessage.plainText(fromHTML:)) ?? ""
            let excerpt = (input.html.flatMap(Email.nonEmpty) == nil ? "" : "[HTML] ") + String(text.prefix(600))
            return ToolPreflight(
                tool: Self.definition.identifier,
                risk: risk,
                summary: "Send \"\(subject)\" from \(identity.address.address.raw) to \(recipients.isEmpty ? "the original sender" : recipients.joined(separator: ", ")) via account \(account.identifier)" + (files.isEmpty ? "." : ", attaching \(files.map(\.description).joined(separator: ", "))."),
                access: .init(targets: recipients),
                estimates: .init(write: .init(count: 1)),
                preview: .init(command: excerpt),
                sideEffects: ["delivers an email that cannot be recalled", "saves a copy in Sent"],
                policyChecks: ["account_sending_policy:\(account.sending.rawValue)", "access_profile:\(runtime.access.name)"],
                warnings: policy == .drafts ? [Email.Failure.sendingNotAllowed(account: account.identifier).localizedDescription] : []
            )
        }

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let authorization = try await Email.authorization(in: context)
            let runtime = authorization.runtime
            let account = try runtime.account(input.account)
            // Enforced here too, whatever the host's approval mode.
            try runtime.access.checkSending()
            guard runtime.access.sending(for: account) != .drafts else {
                throw Email.Failure.sendingNotAllowed(account: account.identifier)
            }

            let composed = try await Email.compose(input, with: authorization, in: context, grantRequired: false)
            // Fixed before rendering twice, so the Sent copy is the delivered message.
            var message = composed.message
            message.messageID = "\(UUID().uuidString)@\(message.from.address.domain)"
            message.date = Date()
            let data = MailRenderer(keepsBcc: true).data(message)
            let delivery = try await runtime.smtp(account).send(message)

            var warnings: [String] = []
            var copy: String?
            if account.savesSentMail {
                copy = "Sent (filed by the provider)"
            } else if account.imap != nil {
                do {
                    copy = try await runtime.imap(account).session { session in
                        guard let folder = try await Email.folder(.sent, for: account, in: session, fallback: nil) else {
                            return nil
                        }
                        try await session.append(data, to: folder, flags: [.seen])
                        return folder
                    }
                    if copy == nil {
                        warnings.append("No Sent folder is known (set folders.sent on the account); no copy was saved.")
                    }
                } catch {
                    warnings.append("Sent, but saving a copy failed: \(error.localizedDescription)")
                }
            }

            return Output(
                account: account.identifier,
                from: Email.display(message.from),
                accepted: delivery.accepted.map(\.raw),
                rejected: delivery.rejected.map { "\($0.recipient.raw): \($0.reply)" },
                sent_copy: copy,
                warnings: warnings
            )
        }
    }
}
