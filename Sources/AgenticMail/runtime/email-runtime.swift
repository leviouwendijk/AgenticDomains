import Agentic
import Errors
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
                throw Failure.cannotRead(account.identifier, reason: account.unavailable[.imap])
            }
            return client
        }

        public func smtp(
            _ account: MailAccounts.Account
        ) throws -> SMTPClient {
            guard let client = accounts.smtpClient(for: account, connector: connector) else {
                throw Failure.cannotSend(account.identifier, reason: account.unavailable[.smtp])
            }
            return client
        }
    }

    enum Failure: Error, Sendable, SemanticError, ErrorNamespaced, ErrorDispositionProviding {
        case missing(expected: String)
        case invalid(file: String, message: String)
        case notProvided
        case noAccounts
        case unknownAccount(String, known: [String])
        case cannotRead(String, reason: String?)
        case cannotSend(String, reason: String?)
        case sendingNotAllowed(account: String)
        case unknownIdentity(String, account: String, known: [String])
        case invalidAddress(String)
        case invalidDate(String)
        case missingSubject
        case noRecipients
        case messageNotFound(uid: Int, mailbox: String)
        case noAttachments(uid: Int, mailbox: String)
        case missingBody
        case attachmentOutside(String, roots: [String])
        case attachmentMissing(String)
        case attachmentsTooLarge(bytes: Int, limit: Int)
        case unknownAttachment(String, known: [String])
        case accessNotProvided
        case accessRequired(level: Level, target: String)
        case noMailboxes(String)
        case missingReason
        case missingTargets
        case unknownLevel(String)
        /// A tool input that cannot work as given; the message says what to change.
        case invalidInput(String)

        public static let errorNamespace = "agentic_mail"

        public var errorCode: String {
            switch self {
            case .missing: return "configuration_missing"
            case .invalid: return "configuration_invalid"
            case .notProvided: return "not_provided"
            case .noAccounts: return "no_accounts"
            case .unknownAccount: return "unknown_account"
            case .cannotRead: return "cannot_read"
            case .cannotSend: return "cannot_send"
            case .sendingNotAllowed: return "sending_not_allowed"
            case .unknownIdentity: return "unknown_identity"
            case .invalidAddress: return "invalid_address"
            case .invalidDate: return "invalid_date"
            case .missingSubject: return "missing_subject"
            case .noRecipients: return "no_recipients"
            case .messageNotFound: return "message_not_found"
            case .noAttachments: return "no_attachments"
            case .missingBody: return "missing_body"
            case .attachmentOutside: return "attachment_outside"
            case .attachmentMissing: return "attachment_missing"
            case .attachmentsTooLarge: return "attachments_too_large"
            case .unknownAttachment: return "unknown_attachment"
            case .accessNotProvided: return "access_not_provided"
            case .accessRequired: return "access_required"
            case .noMailboxes: return "no_mailboxes"
            case .missingReason: return "missing_reason"
            case .missingTargets: return "missing_targets"
            case .unknownLevel: return "unknown_level"
            case .invalidInput: return "invalid_input"
            }
        }

        public var errorPresentation: ErrorPresentation {
            switch self {
            case .missing(let expected):
                return .init(
                    message: "Mail is not configured: no .frame file in \(expected).",
                    recoverySuggestion: "`email example > \(expected)/accounts.frame` writes one to start from; `email check` validates it."
                )
            case .invalid(let file, let message):
                return .init(
                    message: "Mail configuration \(file) is invalid.",
                    reason: message,
                    recoverySuggestion: "`email check` validates it."
                )
            case .notProvided:
                return .init(message: "This application does not provide mail for its sessions.")
            case .noAccounts:
                return .init(message: "The mail configuration declares no accounts.")
            case .unknownAccount(let name, let known):
                return .init(
                    message: "No account '\(name)'.",
                    recoverySuggestion: "Known accounts: \(known.joined(separator: ", "))."
                )
            case .cannotRead(let account, let reason):
                return .init(
                    message: "Account '\(account)' cannot be read.",
                    reason: reason ?? "It has no IMAP server.",
                    recoverySuggestion: Self.configurationSuggestion(reason)
                )
            case .cannotSend(let account, let reason):
                return .init(
                    message: "Account '\(account)' cannot send.",
                    reason: reason ?? "It has no SMTP server.",
                    recoverySuggestion: Self.configurationSuggestion(reason)
                )
            case .sendingNotAllowed(let account):
                return .init(
                    message: "Account '\(account)' only allows drafts (sending = drafts).",
                    recoverySuggestion: "Save a draft with mail_tool_draft; the owner sends it."
                )
            case .unknownIdentity(let address, let account, let known):
                return .init(
                    message: "Account '\(account)' does not send as \(address).",
                    reason: "Its identities: \(known.joined(separator: ", ")).",
                    messageSensitivity: .potentially_sensitive,
                    reasonSensitivity: .potentially_sensitive
                )
            case .invalidAddress(let address):
                return .init(
                    message: "'\(address)' is not a valid email address.",
                    messageSensitivity: .potentially_sensitive
                )
            case .invalidDate(let date):
                return .init(
                    message: "'\(date)' is not a date.",
                    recoverySuggestion: "Write dates as yyyy-MM-dd."
                )
            case .missingSubject:
                return .init(message: "A new message needs a subject.")
            case .noRecipients:
                return .init(message: "A message needs at least one recipient in to, cc or bcc.")
            case .messageNotFound(let uid, let mailbox):
                return .init(
                    message: "No message with UID \(uid) in \(mailbox).",
                    recoverySuggestion: "UIDs belong to one mailbox; search or list that mailbox again for current ones.",
                    messageSensitivity: .potentially_sensitive
                )
            case .noAttachments(let uid, let mailbox):
                return .init(
                    message: "Message \(uid) in \(mailbox) has no attachments.",
                    messageSensitivity: .potentially_sensitive
                )
            case .missingBody:
                return .init(message: "Give the message a body, html or both.")
            case .attachmentOutside(let path, let roots):
                return .init(
                    message: "'\(path)' is outside where attachments may come from.",
                    reason: "Attachments may come from: \(roots.joined(separator: ", ")).",
                    recoverySuggestion: "Save or export the file there first.",
                    messageSensitivity: .potentially_sensitive,
                    reasonSensitivity: .potentially_sensitive
                )
            case .attachmentMissing(let path):
                return .init(
                    message: "No file at '\(path)'.",
                    messageSensitivity: .potentially_sensitive
                )
            case .attachmentsTooLarge(let bytes, let limit):
                return .init(
                    message: "The attachments total \(bytes / 1_048_576) MB.",
                    reason: "At most \(limit / 1_048_576) MB fit in one message."
                )
            case .unknownAttachment(let name, let known):
                return .init(
                    message: "No attachment named '\(name)'.",
                    recoverySuggestion: "This message has: \(known.joined(separator: ", "))."
                )
            case .accessNotProvided:
                return .init(message: "This application keeps no mail access for its sessions (Email.SessionAccess), so mail cannot be read.")
            case .accessRequired(let level, let target):
                return .init(
                    message: "No \(level.rawValue) access to \(target) in this session.",
                    recoverySuggestion: "Ask for it with mail_tool_request_access (targets [\"\(target)\"], level \(level.rawValue)) and a reason."
                )
            case .missingReason:
                return .init(message: "Say why the task needs this access; the owner sees the reason.")
            case .missingTargets:
                return .init(message: "Name targets (selectors such as leads or hondenmeesters:@junk) or a profile.")
            case .unknownLevel(let level):
                return .init(
                    message: "Unknown level '\(level)'.",
                    recoverySuggestion: "Use read, draft or organize."
                )
            case .invalidInput(let message):
                return .init(message: message)
            case .noMailboxes(let selectors):
                return .init(
                    message: "No mailbox matches \(selectors).",
                    recoverySuggestion: "List them with mail_tool_mailboxes."
                )
            }
        }

        public var errorDiagnosticFields: [ErrorDiagnosticField] {
            switch self {
            case .messageNotFound(let uid, let mailbox), .noAttachments(let uid, let mailbox):
                return [
                    .init(key: "uid", value: uid),
                    .init(key: "mailbox", value: mailbox, sensitivity: .potentially_sensitive),
                ]
            case .accessRequired(let level, let target):
                return [
                    .init(key: "level", value: level.rawValue),
                    .init(key: "target", value: target),
                ]
            case .attachmentsTooLarge(let bytes, let limit):
                return [
                    .init(key: "bytes", value: bytes),
                    .init(key: "limit", value: limit),
                ]
            default:
                return []
            }
        }

        public var errorDisposition: ErrorDisposition? {
            switch self {
            case .missing, .invalid, .notProvided, .noAccounts, .cannotRead, .cannotSend, .accessNotProvided:
                return .requires_configuration
            case .sendingNotAllowed, .attachmentOutside, .accessRequired:
                return .requires_access
            case .unknownAccount, .unknownIdentity, .invalidAddress, .invalidDate, .missingSubject,
                 .noRecipients, .messageNotFound, .noAttachments, .missingBody, .attachmentMissing,
                 .attachmentsTooLarge, .unknownAttachment, .noMailboxes, .missingReason,
                 .missingTargets, .unknownLevel, .invalidInput:
                return .invalid_input
            }
        }

        /// A server left out for a missing setting names the setting.
        private static func configurationSuggestion(
            _ reason: String?
        ) -> String? {
            guard let reason, reason.contains("environment variable") else {
                return nil
            }
            return "Set that variable in the environment the host runs with."
        }
    }

    /// The session's runtime: inserted directly, or from the configuration
    /// store in the services; otherwise the library's default store, which
    /// reads every root's `.config/mail/*.frame` and reloads when a file or
    /// `~/.config/roots.frame` changes. An
    /// inserted `Scope` limits it to that access profile.
    static func runtime(
        in context: CapabilityContext
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
