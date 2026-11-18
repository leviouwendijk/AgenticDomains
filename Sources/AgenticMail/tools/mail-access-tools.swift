import Agentic
import Foundation
import Mail
import MailFrame
import Macros
import Schema

public extension Email.Tools {
    @Tool("mail_request_access")
    struct RequestAccess {
        @JSONSchema
        public struct Input: HashableSource {
            /// What to open, as selectors: an account, a group or *, optionally with :mailbox, :prefix/* or :@role,
            /// as in `leads`, `hondenmeesters:@junk` or `levi:INBOX/Klanten/*`.
            public let targets: [String]?
            /// A configured access profile to open instead of targets.
            public let profile: String?
            /// read (the default) or draft; draft includes read and allows drafting and, per approved message, sending.
            public let level: String?
            /// Why the task needs it, for the owner who approves.
            public let reason: String

            public init(targets: [String]? = nil, profile: String? = nil, level: String? = nil, reason: String) {
                self.targets = targets
                self.profile = profile
                self.level = level
                self.reason = reason
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            /// What this request granted, such as `read hondenmeesters:@junk`.
            public let granted: [String]
            /// Every grant of this session.
            public let session: [String]
        }

        public static let purpose =
            "Ask the owner for access to mail for this session: accounts, groups or mailboxes by selector (or a configured profile), at read or draft level, with a reason. Nothing beyond account metadata can be read until a request is approved."
        public static let risk: ActionRisk = .privileged

        public init() {}

        /// Always reviewed: the owner sees exactly which accounts and mailboxes would open, and why.
        public func preflight(_ input: Input, in context: ToolContext) async throws -> ToolPreflight {
            let runtime = try Email.runtime(in: context)
            let grants = try Self.grants(input, runtime: runtime)
            let accounts = try grants.flatMap { try $0.selector.accounts(in: runtime.accounts).map(\.identifier) }
            var seen: Set<String> = []
            let unique = accounts.filter { seen.insert($0).inserted }
            return ToolPreflight(
                tool: Self.definition.identifier,
                risk: Self.definition.risk,
                summary: "Grant \(grants.map(\.description).joined(separator: ", ")) for this session (accounts: \(unique.joined(separator: ", "))). Reason: \(input.reason)",
                access: .init(targets: grants.map(\.selector.description)),
                sideEffects: ["opens the named mail to the agent until the session ends"],
                policyChecks: ["session_scoped_grant", "access_profile:\(runtime.access.name)"]
            )
        }

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try Email.runtime(in: context)
            guard let access = try? context.require(Email.SessionAccess.self) else {
                throw Email.Failure.accessNotProvided
            }
            let grants = try Self.grants(input, runtime: runtime)
            await access.add(grants)
            return Output(
                granted: grants.map(\.description),
                session: await access.grants.map(\.description)
            )
        }

        /// The grants a request asks for, refused when they reach past the session's profile.
        static func grants(
            _ input: Input,
            runtime: Email.Runtime
        ) throws -> [Email.Grant] {
            guard let reason = Email.nonEmpty(input.reason) else {
                throw Email.Failure.missingReason
            }
            let level = try input.level.flatMap(Email.nonEmpty).map { text in
                guard let level = Email.Level(rawValue: text.lowercased()) else {
                    throw Email.Failure.unknownLevel(text)
                }
                return level
            } ?? .read

            var grants: [Email.Grant] = []
            if let name = input.profile.flatMap(Email.nonEmpty) {
                let profile = try runtime.accounts.access(named: name)
                let profileLevel: Email.Level = profile.mayDraft ? min(level, .draft) : .read
                let targets: [MailSelector.Target] = profile.accounts.map { $0.map(MailSelector.Target.name) } ?? [.all]
                let mailboxes: [MailSelector.Mailboxes] = profile.mailboxes.map { $0.map(MailSelector.Mailboxes.pattern) } ?? [.unspecified]
                for target in targets {
                    for mailbox in mailboxes {
                        grants.append(Email.Grant(MailSelector(target: target, mailboxes: mailbox), level: profileLevel, reason: reason))
                    }
                }
            }
            for target in input.targets ?? [] {
                grants.append(Email.Grant(try MailSelector(parsing: target), level: level, reason: reason))
            }
            guard !grants.isEmpty else {
                throw Email.Failure.missingTargets
            }

            // Within the session's profile: every account a grant names must be visible to it.
            for grant in grants {
                for account in try grant.selector.accounts(in: runtime.accounts) where grant.selector.target != .all {
                    try runtime.access.check(account: account.identifier)
                }
                if grant.level == .draft {
                    try runtime.access.checkDrafting()
                }
            }
            return grants
        }
    }
}
