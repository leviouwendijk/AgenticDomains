import Agentic
import Foundation
import IMAP
import Mail
import MailFrame

public extension Email {
    /// What a grant allows: reading, or reading plus drafting. Sending is approved
    /// per message; a draft grant only lets an account whose policy is `allowed`
    /// send without that approval.
    enum Level: String, Sendable, Hashable, Codable, CaseIterable, Comparable {
        case read
        case draft

        public static func < (
            lhs: Level,
            rhs: Level
        ) -> Bool {
            allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
        }
    }

    /// Access granted in this session to what a selector picks.
    struct Grant: Sendable, Hashable, CustomStringConvertible {
        public let selector: MailSelector
        public let level: Level
        public let reason: String

        public init(
            _ selector: MailSelector,
            level: Level,
            reason: String
        ) {
            self.selector = selector
            self.level = level
            self.reason = reason
        }

        public var description: String {
            "\(level.rawValue) \(selector)"
        }
    }

    /// The grants of one session. The host inserts a fresh one into each
    /// session's services; without it, mail reads nothing. Grants only ever
    /// come from approved `mail_request_access` calls or from the host.
    actor SessionAccess {
        public private(set) var grants: [Grant]

        public init(
            grants: [Grant] = []
        ) {
            self.grants = grants
        }

        public func add(
            _ new: [Grant]
        ) {
            for grant in new where !grants.contains(grant) {
                grants.append(grant)
            }
        }
    }

    /// The session's runtime and grants, answering what the agent may touch.
    struct Authorization: Sendable {
        public let runtime: Runtime
        public let grants: [Grant]

        /// The highest level granted for `mailbox` of `account`; with no mailbox,
        /// for the account itself (any grant on it counts, as for drafting).
        public func level(
            account: MailAccounts.Account,
            mailbox: (name: String, role: MailboxRole?)? = nil
        ) -> Level? {
            grants
                .filter { $0.selector.matches(account: account) }
                .filter { grant in
                    guard let mailbox else {
                        return true
                    }
                    return grant.selector.matches(mailbox: mailbox.name, role: mailbox.role)
                }
                .map(\.level)
                .max()
        }

        /// Whether checking a mailbox on `account` needs the server's roles.
        public func needsRoles(
            for account: MailAccounts.Account
        ) -> Bool {
            grants.contains { grant in
                guard grant.selector.matches(account: account), case .role = grant.selector.mailboxes else {
                    return false
                }
                return true
            }
        }

        public func require(
            _ level: Level,
            account: MailAccounts.Account,
            mailbox: (name: String, role: MailboxRole?)? = nil
        ) throws {
            guard let granted = self.level(account: account, mailbox: mailbox), granted >= level else {
                let target = mailbox.map { "\(account.identifier):\($0.name)" } ?? account.identifier
                throw Failure.accessRequired(level: level, target: target)
            }
        }
    }

    /// The runtime with the session's grants; fails when the host keeps no session access.
    static func authorization(
        in context: ToolContext
    ) async throws -> Authorization {
        let runtime = try runtime(in: context)
        guard let access = try? context.require(SessionAccess.self) else {
            throw Failure.accessNotProvided
        }
        return Authorization(runtime: runtime, grants: await access.grants)
    }

    /// A mailbox's role on `account`, listing the server only when a role grant needs it.
    static func role(
        of mailbox: String,
        account: MailAccounts.Account,
        authorization: Authorization,
        session: IMAPSession
    ) async throws -> MailboxRole? {
        let listed = authorization.needsRoles(for: account) ? try await session.list() : []
        return MailboxRole.of(mailbox, account: account, listed: listed)
    }
}
