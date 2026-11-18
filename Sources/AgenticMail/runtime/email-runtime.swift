import Agentic
import Foundation
import IMAP
import Mail
import MailConnection
import MailFrame
import SMTP

public extension Email {
    /// Loaded accounts plus how to reach their servers.
    struct Runtime: Sendable {
        public let accounts: MailAccounts
        public let connector: MailConnector

        public init(
            accounts: MailAccounts,
            connector: @escaping MailConnector = MailServerConfiguration.networkConnector
        ) {
            self.accounts = accounts
            self.connector = connector
        }

        /// `identifier`'s account, or the default when nil.
        public func account(
            _ identifier: String?
        ) throws -> MailAccounts.Account {
            let known = accounts.accounts.map(\.identifier)
            guard let identifier = identifier.flatMap(Email.nonEmpty) else {
                guard let account = accounts.defaultAccount else {
                    throw Failure.noAccounts
                }
                return account
            }
            guard let account = accounts.account(named: identifier) else {
                throw Failure.unknownAccount(identifier, known: known)
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

    /// Where the application keeps `mail.frame` and how it loads it; `state()`
    /// loads on every call so a saved file applies within the session.
    struct ConfigurationStore: Sendable {
        public let file: URL
        private let load: @Sendable () -> ConfigurationState

        public init(
            file: URL,
            load: @escaping @Sendable () -> ConfigurationState
        ) {
            self.file = file
            self.load = load
        }

        public func state() -> ConfigurationState {
            load()
        }
    }

    enum ConfigurationState: Sendable {
        case loaded(Runtime)
        case missing(expected: String)
        case invalid(file: String, message: String)
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
                return "Mail is not configured: no \(MailFrame.fileName) at \(expected). `agentic example mail` prints one to start from."
            case .invalid(let file, let message):
                return "Mail configuration \(file) is invalid: \(message)"
            case .notProvided:
                return "This application does not provide mail for its sessions."
            case .noAccounts:
                return "\(MailFrame.fileName) declares no accounts."
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

    /// The session's runtime: inserted directly, from the store's current file,
    /// or from an inserted `ConfigurationState`; otherwise why there is none.
    static func runtime(
        in context: ToolContext
    ) throws -> Runtime {
        if let runtime = try? context.require(Runtime.self) {
            return runtime
        }
        let state: ConfigurationState
        if let store = try? context.require(ConfigurationStore.self) {
            state = store.state()
        } else if let inserted = try? context.require(ConfigurationState.self) {
            state = inserted
        } else {
            throw Failure.notProvided
        }
        switch state {
        case .loaded(let runtime):
            return runtime
        case .missing(let expected):
            throw Failure.missing(expected: expected)
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
