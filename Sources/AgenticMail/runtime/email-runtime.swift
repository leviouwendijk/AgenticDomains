import Agentic
import Foundation
import IMAP
import Mail
import MailConnection
import MailFrame
import SMTP

public extension Email {
    /// Loaded accounts plus how to reach their servers.
    /// Limits a session to a named access profile from the mail configuration.
    /// Insert it into the session's tool services; without one, access is unrestricted.
    struct Scope: Sendable, Hashable {
        public let profile: String

        public init(
            _ profile: String
        ) {
            self.profile = profile
        }
    }

    /// Loaded accounts, the session's access profile, and how to reach the servers.
    struct Runtime: Sendable {
        public let accounts: MailAccounts
        public let access: MailAccess
        public let connector: MailConnector

        public init(
            accounts: MailAccounts,
            access: MailAccess = .unrestricted,
            connector: @escaping MailConnector = MailServerConfiguration.networkConnector
        ) {
            self.accounts = accounts
            self.access = access
            self.connector = connector
        }

        /// The same accounts under another profile.
        public func limited(
            to access: MailAccess
        ) -> Runtime {
            Runtime(accounts: accounts, access: access, connector: connector)
        }

        /// `identifier`'s account, or the first the profile can see when nil.
        public func account(
            _ identifier: String?
        ) throws -> MailAccounts.Account {
            let visible = access.visibleAccounts(in: accounts)
            guard let identifier = identifier.flatMap(Email.nonEmpty) else {
                guard let account = visible.first else {
                    throw Failure.noAccounts
                }
                return account
            }
            try access.check(account: identifier)
            guard let account = accounts.account(named: identifier) else {
                throw Failure.unknownAccount(identifier, known: visible.map(\.identifier))
            }
            return account
        }

        public func imap(
            _ account: MailAccounts.Account
        ) throws -> IMAPClient {
            guard let client = accounts.imapClient(for: account, connector: connector) else {
                throw Failure.cannotRead(account.identifier)
            }
            return client
        }

        public func smtp(
            _ account: MailAccounts.Account
        ) throws -> SMTPClient {
            guard let client = accounts.smtpClient(for: account, connector: connector) else {
                throw Failure.cannotSend(account.identifier)
            }
            return client
        }
    }

    enum Failure: Error, Sendable, LocalizedError {
        case missing(expected: String)
        case invalid(file: String, message: String)
        case notProvided
        case noAccounts
        case unknownAccount(String, known: [String])
        case cannotRead(String)
        case cannotSend(String)
        case sendingNotAllowed(account: String)
        case unknownIdentity(String, account: String, known: [String])
        case invalidAddress(String)
        case invalidDate(String)
        case missingSubject
        case noRecipients
        case messageNotFound(uid: Int, mailbox: String)

        public var errorDescription: String? {
            switch self {
            case .missing(let expected):
                return "Mail is not configured: no .frame file in \(expected). `email example > \(expected)/accounts.frame` writes one to start from; `email check` validates it."
            case .invalid(let file, let message):
                return "Mail configuration \(file) is invalid: \(message)"
            case .notProvided:
                return "This application does not provide mail for its sessions."
            case .noAccounts:
                return "The mail configuration declares no accounts."
            case .unknownAccount(let name, let known):
                return "No account '\(name)'; known accounts: \(known.joined(separator: ", "))."
            case .cannotRead(let account):
                return "Account '\(account)' has no IMAP server, so it cannot be read."
            case .cannotSend(let account):
                return "Account '\(account)' has no SMTP server, so it cannot send."
            case .sendingNotAllowed(let account):
                return "Account '\(account)' only allows drafts (sending = drafts). Save a draft with mail_draft; the owner sends it."
            case .unknownIdentity(let address, let account, let known):
                return "Account '\(account)' does not send as \(address); its identities: \(known.joined(separator: ", "))."
            case .invalidAddress(let address):
                return "'\(address)' is not a valid email address."
            case .invalidDate(let date):
                return "'\(date)' is not a date in yyyy-MM-dd form."
            case .missingSubject:
                return "A new message needs a subject."
            case .noRecipients:
                return "A message needs at least one recipient in to, cc or bcc."
            case .messageNotFound(let uid, let mailbox):
                return "No message with UID \(uid) in \(mailbox)."
            }
        }
    }

    /// The session's runtime: inserted directly, or from the configuration
    /// store in the services; otherwise the library's default store, which
    /// reads `~/.config/mail/*.frame` and reloads when a file changes. An
    /// inserted `Scope` limits it to that access profile.
    static func runtime(
        in context: ToolContext
    ) throws -> Runtime {
        let scope = try? context.require(Scope.self)
        if let runtime = try? context.require(Runtime.self) {
            guard let scope else {
                return runtime
            }
            return runtime.limited(to: try runtime.accounts.access(named: scope.profile))
        }
        let store = (try? context.require(MailConfigurationStore.self)) ?? .standard
        switch store.state() {
        case .loaded(let accounts):
            return Runtime(accounts: accounts, access: try accounts.access(named: scope?.profile))
        case .missing(let directory):
            throw Failure.missing(expected: directory)
        case .invalid(let file, let message):
            throw Failure.invalid(file: file, message: message)
        }
    }

    static func nonEmpty(
        _ text: String
    ) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func display(
        _ address: NamedAddress
    ) -> String {
        address.name.map { "\($0) <\(address.address.raw)>" } ?? address.address.raw
    }

    static func timestamp(
        _ date: Date?
    ) -> String? {
        date.map { $0.formatted(.iso8601) }
    }

    /// `yyyy-MM-dd` in the current zone.
    static func day(
        _ text: String
    ) throws -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: text.trimmingCharacters(in: .whitespaces)) else {
            throw Failure.invalidDate(text)
        }
        return date
    }

    /// The folder for `role`: the file's override, the server's SPECIAL-USE, then `fallback`.
    static func folder(
        _ role: IMAPSpecialUse,
        for account: MailAccounts.Account,
        in session: IMAPSession,
        fallback: String?
    ) async throws -> String? {
        if let configured = account.folders[role] {
            return configured
        }
        return try await session.mailbox(for: role)?.name ?? fallback
    }
}
