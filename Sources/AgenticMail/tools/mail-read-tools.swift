import Agentic
import Foundation
import IMAP
import Mail
import MailFrame
import Macros
import Schema

public extension Email.Tools {
    @Tool("mail_accounts")
    struct ListAccounts {
        @JSONSchema
        public struct Input: HashableSource {
            public init() {}
        }

        @JSONSchema
        public struct IdentitySummary: HashableResult {
            public let address: String
            public let name: String?
            public let has_signature: Bool
        }

        @JSONSchema
        public struct AccountSummary: HashableResult {
            public let account: String
            public let is_default: Bool
            public let about: String?
            /// The first identity is the account's default sender.
            public let identities: [IdentitySummary]
            public let can_read: Bool
            public let can_send: Bool
            /// drafts: only drafts, the owner sends; confirm: each send needs the owner's approval; allowed: may send.
            public let sending: String
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let accounts: [AccountSummary]
        }

        public static let purpose =
            "List the configured mail accounts: their identities (From addresses), whether each can read and send, and its sending policy. Never shows servers or passwords."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Email.runtime(in: context)
            let accounts = runtime.accounts.accounts
            return Output(accounts: accounts.enumerated().map { index, account in
                AccountSummary(
                    account: account.identifier,
                    is_default: index == 0,
                    about: account.about,
                    identities: account.identities.map {
                        IdentitySummary(address: $0.address.address.raw, name: $0.address.name, has_signature: $0.signature != nil)
                    },
                    can_read: account.imap != nil,
                    can_send: account.smtp != nil,
                    sending: account.sending.rawValue
                )
            })
        }
    }

    @Tool("mail_mailboxes")
    struct ListMailboxes {
        @JSONSchema
        public struct Input: HashableSource {
            /// The account's binding name; the default account when absent.
            public let account: String?
            /// Also report total and unread counts per mailbox (one request each).
            public let counts: Bool?

            public init(account: String? = nil, counts: Bool? = nil) {
                self.account = account
                self.counts = counts
            }
        }

        @JSONSchema
        public struct MailboxSummary: HashableResult {
            /// The full name to pass as `mailbox`, such as `INBOX/Clients`.
            public let name: String
            /// sent, drafts, archive, trash, junk, all or flagged, when the server or file says so.
            public let role: String?
            public let selectable: Bool
            public let total: Int?
            public let unread: Int?
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let account: String
            public let mailboxes: [MailboxSummary]
        }

        public static let purpose =
            "List an account's mailboxes (folders and subfolders) with their roles, optionally with total and unread counts. Read-only."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Email.runtime(in: context)
            let account = try runtime.account(input.account)
            let overrides = Dictionary(account.folders.map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            let counted = input.counts ?? false

            let mailboxes = try await runtime.imap(account).session { session in
                var summaries: [MailboxSummary] = []
                for mailbox in try await session.list() {
                    let status = counted && mailbox.isSelectable ? try? await session.status(mailbox.name) : nil
                    summaries.append(MailboxSummary(
                        name: mailbox.name,
                        role: (overrides[mailbox.name] ?? mailbox.specialUse)?.rawValue,
                        selectable: mailbox.isSelectable,
                        total: status?.messages,
                        unread: status?.unseen
                    ))
                }
                return summaries
            }
            return Output(account: account.identifier, mailboxes: mailboxes)
        }
    }

    @Tool("mail_search")
    struct Search {
        @JSONSchema
        public struct Input: HashableSource {
            /// The account's binding name; the default account when absent.
            public let account: String?
            /// The mailbox's full name from mail_mailboxes; INBOX when absent.
            public let mailbox: String?
            /// true: only unread; false: only read; absent: both.
            public let unread: Bool?
            /// true: only flagged; false: only unflagged; absent: both.
            public let flagged: Bool?
            /// Substring of the From header (name or address).
            public let from: String?
            /// Substring of the To header.
            public let to: String?
            /// Substring of the subject.
            public let subject: String?
            /// Substring anywhere in headers or body.
            public let text: String?
            /// Received on or after this day, yyyy-MM-dd.
            public let since: String?
            /// Received before this day, yyyy-MM-dd.
            public let before: String?
            /// Most recent matches to return; 20 when absent, at most 100.
            public let limit: Int?

            public init(
                account: String? = nil,
                mailbox: String? = nil,
                unread: Bool? = nil,
                flagged: Bool? = nil,
                from: String? = nil,
                to: String? = nil,
                subject: String? = nil,
                text: String? = nil,
                since: String? = nil,
                before: String? = nil,
                limit: Int? = nil
            ) {
                self.account = account
                self.mailbox = mailbox
                self.unread = unread
                self.flagged = flagged
                self.from = from
                self.to = to
                self.subject = subject
                self.text = text
                self.since = since
                self.before = before
                self.limit = limit
            }
        }

        @JSONSchema
        public struct MessageSummary: HashableResult {
            /// Pass to mail_read or as reply_to_uid.
            public let uid: Int
            public let date: String?
            public let from: [String]
            public let to: [String]
            public let subject: String?
            public let unread: Bool
            public let flagged: Bool
            public let answered: Bool
            public let size: Int?
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let account: String
            public let mailbox: String
            /// All matches; `messages` holds the most recent `limit`, newest first.
            public let total_matches: Int
            public let messages: [MessageSummary]
        }

        public static let purpose =
            "Search one mailbox on the server by unread/flagged state, sender, recipient, subject, text and received dates; returns the newest matches with sender, subject and flags. Never marks messages read."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Email.runtime(in: context)
            let account = try runtime.account(input.account)
            let mailbox = input.mailbox.flatMap(Email.nonEmpty) ?? "INBOX"
            let query = try Self.query(input)
            let limit = min(max(input.limit ?? 20, 1), 100)

            let (total, summaries) = try await runtime.imap(account).session { session in
                try await session.select(mailbox)
                let uids = try await session.search(query)
                return (uids.count, try await session.summaries(Array(uids.suffix(limit))))
            }

            return Output(
                account: account.identifier,
                mailbox: mailbox,
                total_matches: total,
                messages: summaries.reversed().map { summary in
                    MessageSummary(
                        uid: Int(summary.uid.rawValue),
                        date: Email.timestamp(summary.envelope?.date ?? summary.internalDate),
                        from: (summary.envelope?.from ?? []).map(Email.display),
                        to: (summary.envelope?.to ?? []).map(Email.display),
                        subject: summary.envelope?.subject,
                        unread: summary.isUnread,
                        flagged: summary.flags.contains(.flagged),
                        answered: summary.flags.contains(.answered),
                        size: summary.size
                    )
                }
            )
        }

        static func query(
            _ input: Input
        ) throws -> IMAPSearch {
            var criteria: [IMAPSearch] = []
            if let unread = input.unread {
                criteria.append(unread ? .unseen : .seen)
            }
            if let flagged = input.flagged {
                criteria.append(flagged ? .flagged : .unflagged)
            }
            if let from = input.from.flatMap(Email.nonEmpty) {
                criteria.append(.from(from))
            }
            if let to = input.to.flatMap(Email.nonEmpty) {
                criteria.append(.to(to))
            }
            if let subject = input.subject.flatMap(Email.nonEmpty) {
                criteria.append(.subject(subject))
            }
            if let text = input.text.flatMap(Email.nonEmpty) {
                criteria.append(.text(text))
            }
            if let since = input.since.flatMap(Email.nonEmpty) {
                criteria.append(.since(try Email.day(since)))
            }
            if let before = input.before.flatMap(Email.nonEmpty) {
                criteria.append(.before(try Email.day(before)))
            }
            return .and(criteria)
        }
    }

    @Tool("mail_read")
    struct Read {
        @JSONSchema
        public struct Input: HashableSource {
            /// The account's binding name; the default account when absent.
            public let account: String?
            /// The mailbox holding the message; INBOX when absent.
            public let mailbox: String?
            /// The message's UID from mail_search.
            public let uid: Int
            /// Longest body to return; 20000 characters when absent.
            public let max_characters: Int?

            public init(account: String? = nil, mailbox: String? = nil, uid: Int, max_characters: Int? = nil) {
                self.account = account
                self.mailbox = mailbox
                self.uid = uid
                self.max_characters = max_characters
            }
        }

        @JSONSchema
        public struct AttachmentSummary: HashableResult {
            public let filename: String
            public let content_type: String
            public let bytes: Int
            public let inline: Bool
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let uid: Int
            public let date: String?
            public let from: [String]
            public let to: [String]
            public let cc: [String]
            public let reply_to: [String]
            public let subject: String?
            /// Plain text; an HTML-only message reduced to text.
            public let body: String
            public let truncated: Bool
            public let attachments: [AttachmentSummary]
        }

        public static let purpose =
            "Read one message: headers, plain-text body (HTML reduced to text) and attachment names. Does not mark it read."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Email.runtime(in: context)
            let account = try runtime.account(input.account)
            let mailbox = input.mailbox.flatMap(Email.nonEmpty) ?? "INBOX"

            let message = try await runtime.imap(account).session { session in
                try await session.select(mailbox)
                return try await session.message(IMAPUID(UInt32(clamping: input.uid)))
            }
            guard let message else {
                throw Email.Failure.messageNotFound(uid: input.uid, mailbox: mailbox)
            }

            let body = message.readableText ?? ""
            let limit = max(input.max_characters ?? 20_000, 1)
            return Output(
                uid: input.uid,
                date: Email.timestamp(message.date),
                from: message.from.map(Email.display),
                to: message.to.map(Email.display),
                cc: message.cc.map(Email.display),
                reply_to: message.replyTo.map(Email.display),
                subject: message.subject,
                body: String(body.prefix(limit)),
                truncated: body.count > limit,
                attachments: message.attachments.map {
                    AttachmentSummary(filename: $0.filename, content_type: $0.contentType, bytes: $0.data.count, inline: $0.isInline)
                }
            )
        }
    }
}
