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
            /// Select every account of a group with the group's name, as in `hondenmeesters:@junk`.
            public let group: String?
            public let is_default: Bool
            public let about: String?
            /// The first identity is the account's default sender.
            public let identities: [IdentitySummary]
            public let can_read: Bool
            public let can_send: Bool
            /// Why reading or sending is off when the environment lacks a setting, as in `imap: … is unset`.
            public let unavailable: [String]?
            /// drafts: only drafts, the owner sends; confirm: each send needs the owner's approval; allowed: may send.
            public let sending: String
            /// The only mailboxes this session may ever read, when its access profile limits them.
            public let mailboxes: [String]?
            /// What this session has been granted on the account: read, draft, or none.
            public let granted: String
        }

        @JSONSchema
        public struct Output: HashableResult {
            /// The access profile limiting this session, if any.
            public let access: String?
            public let groups: [String]
            public let accounts: [AccountSummary]
            /// Grants of this session, such as `read hondenmeesters:@junk`.
            public let grants: [String]
        }

        public static let purpose =
            "List the configured mail accounts and groups (metadata only: identities, what each is for, sending policy) and what this session has been granted. No message content; needs no access."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Email.runtime(in: context)
            let grants = (try? await Email.authorization(in: context))?.grants ?? []
            let authorization = Email.Authorization(runtime: runtime, grants: grants)
            let access = runtime.access
            let accounts = access.visibleAccounts(in: runtime.accounts)
            return Output(
                access: access == .unrestricted ? nil : access.name,
                groups: runtime.accounts.groups,
                accounts: accounts.enumerated().map { index, account in
                    AccountSummary(
                        account: account.identifier,
                        group: account.group,
                        is_default: index == 0,
                        about: account.about,
                        identities: access.identities(of: account).map {
                            IdentitySummary(address: $0.address.address.raw, name: $0.address.name, has_signature: $0.signature != nil)
                        },
                        can_read: account.imap != nil,
                        can_send: account.smtp != nil && access.maySend,
                        unavailable: account.unavailable.isEmpty ? nil : account.unavailable
                            .sorted { $0.key.rawValue < $1.key.rawValue }
                            .map { "\($0.key.rawValue): \($0.value)" },
                        sending: access.sending(for: account).rawValue,
                        mailboxes: access.mailboxes,
                        granted: authorization.level(account: account)?.rawValue ?? "none"
                    )
                },
                grants: grants.map(\.description)
            )
        }
    }

    @Tool("mail_mailboxes")
    struct ListMailboxes {
        @JSONSchema
        public struct Input: HashableSource {
            /// The account's name; the default account when absent.
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
            /// The full name to pass as `mailbox`, such as `INBOX/Klanten`; Gmail labels appear as mailboxes.
            public let name: String
            /// inbox, sent, drafts, archive, trash, junk, all or flagged, when known; select it as `account:@role`.
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
            "List the mailboxes (folders, subfolders, Gmail labels) of an account that this session may read, with their roles and optional counts."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let authorization = try await Email.authorization(in: context)
            let runtime = authorization.runtime
            let account = try runtime.account(input.account)
            try authorization.require(.read, account: account)
            let counted = input.counts ?? false

            let mailboxes = try await runtime.imap(account).session { session in
                let listed = try await session.list()
                var summaries: [MailboxSummary] = []
                for mailbox in listed where runtime.access.allows(mailbox: mailbox.name) {
                    let role = MailboxRole.of(mailbox.name, account: account, listed: listed)
                    guard authorization.level(account: account, mailbox: (mailbox.name, role)) != nil else {
                        continue
                    }
                    let status = counted && mailbox.isSelectable ? try? await session.status(mailbox.name) : nil
                    summaries.append(MailboxSummary(
                        name: mailbox.name,
                        role: role?.description,
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
            /// Where to search, as selectors: an account, a group or *, optionally with :mailbox, :prefix/* or :@role,
            /// as in `hondenmeesters:@junk` or `levi:INBOX/Klanten/*`. Replaces account and mailbox.
            public let targets: [String]?
            /// The account's name; the default account when absent and `targets` is not given.
            public let account: String?
            /// The mailbox's full name; INBOX when absent.
            public let mailbox: String?
            /// true: only unread; false: only read; absent: both.
            public let unread: Bool?
            /// true: only flagged; false: only unflagged; absent: both.
            public let flagged: Bool?
            /// Substring of the From header (name or address).
            public let from: String?
            /// Substring of the To header only.
            public let to: String?
            /// Substring of the Cc header only.
            public let cc: String?
            /// Substring of the To or the Cc header: mail addressed to someone, either way.
            public let addressed: String?
            /// Substring of the subject.
            public let subject: String?
            /// Substring anywhere in headers or body.
            public let text: String?
            /// Received on or after this day, yyyy-MM-dd.
            public let since: String?
            /// Received before this day, yyyy-MM-dd.
            public let before: String?
            /// Gmail search syntax, such as `has:attachment older_than:7d`; Gmail accounts only.
            public let gmail_query: String?
            /// Every message of one Gmail conversation, by the `thread_id` a search returned.
            public let thread_id: String?
            /// Most recent matches to return; 20 when absent, at most 100.
            public let limit: Int?

            public init(
                targets: [String]? = nil,
                account: String? = nil,
                mailbox: String? = nil,
                unread: Bool? = nil,
                flagged: Bool? = nil,
                from: String? = nil,
                to: String? = nil,
                cc: String? = nil,
                addressed: String? = nil,
                subject: String? = nil,
                text: String? = nil,
                since: String? = nil,
                before: String? = nil,
                gmail_query: String? = nil,
                thread_id: String? = nil,
                limit: Int? = nil
            ) {
                self.targets = targets
                self.account = account
                self.mailbox = mailbox
                self.unread = unread
                self.flagged = flagged
                self.from = from
                self.to = to
                self.cc = cc
                self.addressed = addressed
                self.subject = subject
                self.text = text
                self.since = since
                self.before = before
                self.gmail_query = gmail_query
                self.thread_id = thread_id
                self.limit = limit
            }
        }

        @JSONSchema
        public struct MessageSummary: HashableResult {
            public let account: String
            public let mailbox: String
            /// Pass with account and mailbox to mail_read, or as reply_to_uid.
            public let uid: Int
            public let date: String?
            public let from: [String]
            public let to: [String]
            public let cc: [String]
            public let subject: String?
            public let unread: Bool
            public let flagged: Bool
            public let answered: Bool
            public let size: Int?
            /// The Gmail conversation; search with `thread_id` for all its messages. Gmail only.
            public let thread_id: String?
            /// Gmail labels. Gmail only.
            public let labels: [String]?
        }

        @JSONSchema
        public struct Output: HashableResult {
            /// Every `account:mailbox` searched.
            public let searched: [String]
            /// All matches; `messages` holds the most recent `limit`, newest first.
            public let total_matches: Int
            public let messages: [MessageSummary]
            /// Accounts the targets picked that cannot be read, with the reason.
            public let skipped: [String]
        }

        public static let purpose =
            "Search mailboxes on the server, across accounts and groups with selectors such as hondenmeesters:@junk, by unread/flagged state, sender, recipient, subject, text and received dates (and, on Gmail, Gmail syntax or a thread). Returns the newest matches. Needs read access; never marks messages read."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let authorization = try await Email.authorization(in: context)
            let runtime = authorization.runtime
            let query = try Self.query(input)
            if query.usesGmailExtensions {
                try runtime.access.checkCrossLabelSearch()
            }

            let selectors: [MailSelector]
            if let targets = input.targets, !targets.isEmpty {
                selectors = try targets.map(MailSelector.init(parsing:))
            } else {
                let account = try runtime.account(input.account)
                let mailbox = input.mailbox.flatMap(Email.nonEmpty) ?? "INBOX"
                selectors = [MailSelector(target: .name(account.identifier), mailboxes: .pattern(mailbox))]
            }
            // Refuse before connecting when an account has no grant at all: even folder names are content.
            for selector in selectors {
                for account in try selector.accounts(in: runtime.accounts) {
                    try runtime.access.check(account: account.identifier)
                    try authorization.require(.read, account: account)
                }
            }

            let result = try await runtime.accounts.search(
                query,
                in: selectors,
                limit: min(max(input.limit ?? 20, 1), 100),
                connector: runtime.connector
            ) { account, mailbox, role in
                try runtime.access.check(account: account.identifier)
                try runtime.access.check(mailbox: mailbox)
                try authorization.require(.read, account: account, mailbox: (mailbox, role))
            }
            if result.searched.isEmpty, let skipped = result.skipped.sorted(by: { $0.key < $1.key }).first {
                throw Email.Failure.cannotRead(skipped.key, reason: skipped.value)
            }
            guard !result.searched.isEmpty else {
                throw Email.Failure.noMailboxes(selectors.map(\.description).joined(separator: ", "))
            }

            return Output(
                searched: result.searched,
                total_matches: result.total,
                messages: result.hits.map { hit in
                    let summary = hit.summary
                    return MessageSummary(
                        account: hit.account,
                        mailbox: hit.mailbox,
                        uid: Int(summary.uid.rawValue),
                        date: Email.timestamp(hit.date),
                        from: (summary.envelope?.from ?? []).map(Email.display),
                        to: (summary.envelope?.to ?? []).map(Email.display),
                        cc: (summary.envelope?.cc ?? []).map(Email.display),
                        subject: summary.envelope?.subject,
                        unread: summary.isUnread,
                        flagged: summary.flags.contains(.flagged),
                        answered: summary.flags.contains(.answered),
                        size: summary.size,
                        thread_id: summary.gmail?.threadID,
                        labels: summary.gmail?.labels
                    )
                },
                skipped: result.skipped.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }
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
            if let cc = input.cc.flatMap(Email.nonEmpty) {
                criteria.append(.cc(cc))
            }
            if let addressed = input.addressed.flatMap(Email.nonEmpty) {
                criteria.append(.or(.to(addressed), .cc(addressed)))
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
            if let query = input.gmail_query.flatMap(Email.nonEmpty) {
                criteria.append(.gmail(query))
            }
            if let thread = input.thread_id.flatMap(Email.nonEmpty) {
                criteria.append(.gmailThread(thread))
            }
            return .and(criteria)
        }
    }

    @Tool("mail_read")
    struct Read {
        @JSONSchema
        public struct Input: HashableSource {
            /// The account's name; the default account when absent.
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
            public let account: String
            public let mailbox: String
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
            "Read one message: headers, plain-text body (HTML reduced to text) and attachment names. Needs read access to its mailbox; does not mark it read."
        public static let risk: ActionRisk = .observe

        public init() {}

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

            let body = message.readableText ?? ""
            let limit = max(input.max_characters ?? 20_000, 1)
            return Output(
                account: account.identifier,
                mailbox: mailbox,
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
