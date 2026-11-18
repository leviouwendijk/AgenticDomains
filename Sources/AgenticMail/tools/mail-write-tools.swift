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
            "Compose a message (or a reply to a UID) from an account's identity, signed, and save it in the account's Drafts folder for the owner to review and send. Sends nothing."
        public static let risk: ActionRisk = .boundedmutate

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Email.runtime(in: context)
            let composed = try await Email.compose(input, with: runtime)
            let data = MailRenderer().data(composed.message)

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
            "Send a message (or a reply to a UID) from an account's identity, signed, and save a copy in Sent. Obeys the account's sending policy: refused under drafts, reviewed by the owner under confirm."
        public static let risk: ActionRisk = .privileged

        public init() {}

        /// The account's policy decides the risk: drafts forbids, confirm needs review, allowed is bounded.
        public func preflight(_ input: Input, in context: ToolContext) async throws -> ToolPreflight {
            let runtime = try Email.runtime(in: context)
            let account = try runtime.account(input.account)
            let identity = try Email.identity(input.from, in: account)
            let recipients = try (Email.addresses(input.to) + Email.addresses(input.cc) + Email.addresses(input.bcc))
                .map(\.address.raw)

            let risk: ActionRisk
            switch account.sending {
            case .drafts:
                risk = .forbidden
            case .confirm:
                risk = .privileged
            case .allowed:
                risk = .boundedmutate
            }

            let subject = input.subject.flatMap(Email.nonEmpty)
                ?? input.reply_to_uid.map { "reply to UID \($0)" }
                ?? "(no subject)"
            let excerpt = String(input.body.prefix(600))
            return ToolPreflight(
                tool: Self.definition.identifier,
                risk: risk,
                summary: "Send \"\(subject)\" from \(identity.address.address.raw) to \(recipients.isEmpty ? "the original sender" : recipients.joined(separator: ", ")) via account \(account.identifier).",
                access: .init(targets: recipients),
                estimates: .init(write: .init(count: 1)),
                preview: .init(command: excerpt),
                sideEffects: ["delivers an email that cannot be recalled", "saves a copy in Sent"],
                policyChecks: ["account_sending_policy:\(account.sending.rawValue)"],
                warnings: account.sending == .drafts ? [Email.Failure.sendingNotAllowed(account: account.identifier).localizedDescription] : []
            )
        }

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Email.runtime(in: context)
            let account = try runtime.account(input.account)
            // Enforced here too, whatever the host's approval mode.
            guard account.sending != .drafts else {
                throw Email.Failure.sendingNotAllowed(account: account.identifier)
            }

            let composed = try await Email.compose(input, with: runtime)
            // Fixed before rendering twice, so the Sent copy is the delivered message.
            var message = composed.message
            message.messageID = "\(UUID().uuidString)@\(message.from.address.domain)"
            message.date = Date()
            let data = MailRenderer().data(message)
            let delivery = try await runtime.smtp(account).send(message)

            var warnings: [String] = []
            var copy: String?
            if account.imap != nil {
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
