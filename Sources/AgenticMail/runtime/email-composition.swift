import Agentic
import Foundation
import IMAP
import Mail
import MailFrame
import Macros
import Schema

public extension Email {
    /// What `mail_draft` and `mail_send` take: a new message, or a reply to one.
    @JSONSchema
    struct Composition: HashableSource {
        /// The account's binding name; the default account when absent.
        public let account: String?
        /// The identity's address to send as; the account's first identity when absent.
        public let from: String?
        /// Recipient addresses, optionally with a name: `Jan de Vries <jan@example.org>`. For a reply, defaults to the original sender.
        public let to: [String]?
        public let cc: [String]?
        public let bcc: [String]?
        /// Required for a new message; a reply defaults to `Re: ` plus the original subject.
        public let subject: String?
        /// Plain text. The identity's signature is appended.
        public let body: String
        /// The UID of the message this replies to, as listed by mail_search.
        public let reply_to_uid: Int?
        /// The mailbox holding `reply_to_uid`; INBOX when absent.
        public let reply_mailbox: String?

        public init(
            account: String? = nil,
            from: String? = nil,
            to: [String]? = nil,
            cc: [String]? = nil,
            bcc: [String]? = nil,
            subject: String? = nil,
            body: String,
            reply_to_uid: Int? = nil,
            reply_mailbox: String? = nil
        ) {
            self.account = account
            self.from = from
            self.to = to
            self.cc = cc
            self.bcc = bcc
            self.subject = subject
            self.body = body
            self.reply_to_uid = reply_to_uid
            self.reply_mailbox = reply_mailbox
        }
    }

    /// A composed message and where it comes from.
    struct Composed: Sendable {
        public let account: MailAccounts.Account
        public let identity: MailIdentity
        public let message: MailMessage
    }

    /// Resolves account and identity, fetches the original for a reply, and builds the signed message.
    /// A draft needs a draft grant; a send is approved per message instead (`grantRequired: false`).
    /// A reply always needs read access to the original's mailbox.
    static func compose(
        _ input: Composition,
        with authorization: Authorization,
        grantRequired: Bool = true
    ) async throws -> Composed {
        let runtime = authorization.runtime
        try runtime.access.checkDrafting()
        let account = try runtime.account(input.account)
        if grantRequired {
            try authorization.require(.draft, account: account)
        }
        let identity = try self.identity(input.from, in: account, access: runtime.access)

        var to = try addresses(input.to)
        var subject = input.subject.flatMap(nonEmpty)
        var headers: [MailHeaderField] = []

        if let uid = input.reply_to_uid {
            let mailbox = input.reply_mailbox.flatMap(nonEmpty) ?? "INBOX"
            try runtime.access.check(mailbox: mailbox)
            let original = try await runtime.imap(account).session { session in
                let role = try await Email.role(of: mailbox, account: account, authorization: authorization, session: session)
                try authorization.require(.read, account: account, mailbox: (mailbox, role))
                try await session.select(mailbox)
                return try await session.message(IMAPUID(UInt32(clamping: uid)))
            }
            guard let original else {
                throw Failure.messageNotFound(uid: uid, mailbox: mailbox)
            }
            if to.isEmpty {
                to = original.replyTo.isEmpty ? original.from : original.replyTo
            }
            if subject == nil {
                let previous = original.subject ?? ""
                subject = previous.lowercased().hasPrefix("re:") ? previous : "Re: \(previous)"
            }
            if let id = original.messageID {
                headers.append(MailHeaderField("In-Reply-To", "<\(id)>"))
                headers.append(MailHeaderField("References", (original.references + [id]).map { "<\($0)>" }.joined(separator: " ")))
            }
        }

        let cc = try addresses(input.cc)
        let bcc = try addresses(input.bcc)
        guard !(to.isEmpty && cc.isEmpty && bcc.isEmpty) else {
            throw Failure.noRecipients
        }
        guard let subject else {
            throw Failure.missingSubject
        }

        var message = identity.message(to: to, cc: cc, bcc: bcc, subject: subject, body: .text(input.body))
        message.headers += headers
        return Composed(account: account, identity: identity, message: message)
    }

    /// `address`'s identity, or the first the profile allows when nil.
    static func identity(
        _ address: String?,
        in account: MailAccounts.Account,
        access: MailAccess
    ) throws -> MailIdentity {
        let allowed = access.identities(of: account)
        guard let address = address.flatMap(nonEmpty) else {
            guard let identity = allowed.first else {
                throw MailAccess.Failure.identity(account.defaultIdentity.address.address.raw, profile: access.name)
            }
            return identity
        }
        try access.check(identity: address)
        guard let identity = allowed.first(where: {
            $0.address.address.raw.caseInsensitiveCompare(address) == .orderedSame
        }) else {
            throw Failure.unknownIdentity(address, account: account.identifier, known: allowed.map(\.address.address.raw))
        }
        return identity
    }

    /// Parses `addr` or `Name <addr>` entries.
    static func addresses(
        _ entries: [String]?
    ) throws -> [NamedAddress] {
        try (entries ?? []).compactMap(nonEmpty).map { entry in
            guard let parsed = NamedAddress.parseList(entry).first, NamedAddress.parseList(entry).count == 1 else {
                throw Failure.invalidAddress(entry)
            }
            return parsed
        }
    }
}
