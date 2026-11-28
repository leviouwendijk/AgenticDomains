import Agentic
import Foundation
import IMAP
import Mail
import MailFrame
import MailIndex
import Macros
import Schema

/// The index and plan tools: count and select over a local index of an
/// account, propose server changes as plans, apply approved plans, undo them.
/// The index is a read model of the server; nothing changes mail except an
/// applied plan, which checks every message against the server first.
public extension Email.Tools {
    @Tool("index_sync")
    struct IndexSync {
        @JSONSchema
        public struct Input: HashableSource {
            /// The account's name; the default account when absent.
            public let account: String?

            public init(account: String? = nil) {
                self.account = account
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let account: String
            public let mailboxes: Int
            public let added: Int
            public let removed: Int
            public let flags_changed: Int
            /// Received messages now indexed (sent mail excluded).
            public let messages: Int
            public let unread: Int
            public let senders: Int
        }

        public static let purpose =
            "Bring an account's local index up to date from the server: new messages, flag changes and removals, never bodies. Read-only toward the server. Needed before mail_tool_clutter, mail_tool_suspicious and mail_tool_plan."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: CapabilityContext) async throws -> Output {
            let authorization = try await Email.authorization(in: context)
            let runtime = authorization.runtime
            try Email.requireWholeAccounts(runtime)
            let account = try runtime.account(input.account)
            try authorization.requireWholeAccount(.read, account: account)
            let index = try Email.index(for: account, in: context, creating: true)
            let report = try await runtime.imap(account).session { session in
                try await index.sync(session)
            }
            let totals = try await index.totals()
            return Output(
                account: account.identifier,
                mailboxes: report.mailboxes,
                added: report.added,
                removed: report.removed,
                flags_changed: report.flagsChanged,
                messages: totals.messages,
                unread: totals.unread,
                senders: totals.senders
            )
        }
    }

    @Tool("clutter")
    struct Clutter {
        @JSONSchema
        public struct Input: HashableSource {
            public let account: String?
            /// sender (the default), domain or list.
            public let by: String?
            /// count (the default), bytes or unread.
            public let order: String?
            /// Rows; 30 when absent.
            public let limit: Int?
            public let mailbox: String?
            /// Only messages received more than this many days ago.
            public let older_than_days: Int?
            /// Only senders never written to.
            public let strangers: Bool?

            public init(account: String? = nil, by: String? = nil, order: String? = nil, limit: Int? = nil, mailbox: String? = nil, older_than_days: Int? = nil, strangers: Bool? = nil) {
                self.account = account
                self.by = by
                self.order = order
                self.limit = limit
                self.mailbox = mailbox
                self.older_than_days = older_than_days
                self.strangers = strangers
            }
        }

        @JSONSchema
        public struct Row: HashableResult {
            /// The sender address, domain or List-Id.
            public let key: String
            public let name: String?
            public let count: Int
            public let bytes: Int
            public let unread: Int
            public let answered: Int
            /// Messages carrying an unsubscribe header.
            public let unsubscribable: Int
            public let with_attachments: Int
            /// yyyy-MM-dd.
            public let first: String?
            public let last: String?
            /// Mail was ever sent to this sender (or someone at this domain).
            public let correspondent: Bool
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let account: String
            public let messages: Int
            public let bytes: Int
            public let rows: [Row]
        }

        public static let purpose =
            "The biggest senders, domains or mailing lists in an account's index, with how much is read, answered, unsubscribable or from correspondents. Counts only; no message content."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: CapabilityContext) async throws -> Output {
            let authorization = try await Email.authorization(in: context)
            try Email.requireWholeAccounts(authorization.runtime)
            let account = try authorization.runtime.account(input.account)
            try authorization.requireWholeAccount(.read, account: account)
            let index = try Email.index(for: account, in: context)

            let grouping = try Email.choice(input.by, default: MailIndexGrouping.sender, field: "by")
            let order = try Email.choice(input.order, default: MailIndexOrder.count, field: "order")
            var filter = MailIndexFilter(mailbox: input.mailbox)
            if let days = input.older_than_days {
                filter.receivedBefore = Date().addingTimeInterval(-Double(days) * 86_400)
            }
            if input.strangers == true {
                filter.fromCorrespondent = false
            }
            let totals = try await index.totals(filter)
            let rows = try await index.clutter(by: grouping, filter: filter, order: order, limit: input.limit ?? 30)
            return Output(
                account: account.identifier,
                messages: totals.messages,
                bytes: totals.bytes,
                rows: rows.map { row in
                    Row(
                        key: row.key, name: row.name, count: row.count, bytes: row.bytes, unread: row.unread,
                        answered: row.answered, unsubscribable: row.unsubscribable, with_attachments: row.withAttachments,
                        first: row.first.map(Email.dayText), last: row.last.map(Email.dayText), correspondent: row.correspondent
                    )
                }
            )
        }
    }

    @Tool("suspicious")
    struct Suspicious {
        @JSONSchema
        public struct Input: HashableSource {
            public let account: String?
            /// Only mail received in the last this many days.
            public let days: Int?
            /// The lowest score shown; 50 when absent.
            public let threshold: Int?
            /// Vendor domains known to be real, such as those in the owner context's vendor entries.
            public let trusted: [String]?
            /// Suspects; 30 when absent.
            public let limit: Int?

            public init(account: String? = nil, days: Int? = nil, threshold: Int? = nil, trusted: [String]? = nil, limit: Int? = nil) {
                self.account = account
                self.days = days
                self.threshold = threshold
                self.trusted = trusted
                self.limit = limit
            }
        }

        @JSONSchema
        public struct Suspect: HashableResult {
            public let mailbox: String
            public let uid: Int
            public let score: Int
            public let from: String?
            public let subject: String?
            /// yyyy-MM-dd.
            public let received: String?
            public let attachments: [String]
            /// One per signal, as in `first mail from x@gmail.com` or `dmarc=fail`.
            public let reasons: [String]
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let account: String
            public let total: Int
            public let suspects: [Suspect]
        }

        public static let purpose =
            "Score received mail for fraud and phishing from the index (payment requests from unknown vendors, strangers, free-mail invoices, campaigns, lookalike domains, failed authentication, risky attachments) and list the suspects with every reason. Skips what the owner trusted or dismissed."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: CapabilityContext) async throws -> Output {
            let authorization = try await Email.authorization(in: context)
            let runtime = authorization.runtime
            try Email.requireWholeAccounts(runtime)
            let account = try runtime.account(input.account)
            try authorization.requireWholeAccount(.read, account: account)
            let index = try Email.index(for: account, in: context)

            let policy = MailSuspicionPolicy(
                trustedDomains: Set(input.trusted ?? []),
                ownDomains: Email.ownDomains(runtime.accounts),
                threshold: input.threshold ?? 50
            )
            var filter = MailIndexFilter()
            if let days = input.days {
                filter.receivedSince = Date().addingTimeInterval(-Double(days) * 86_400)
            }
            let suspects = try await index.suspicious(policy, filter: filter)
            return Output(
                account: account.identifier,
                total: suspects.count,
                suspects: suspects.prefix(max(1, input.limit ?? 30)).map { suspect in
                    Suspect(
                        mailbox: suspect.mailbox,
                        uid: Int(suspect.uid.rawValue),
                        score: suspect.score,
                        from: suspect.fromName.map { "\($0) <\(suspect.fromAddress ?? "")>" } ?? suspect.fromAddress,
                        subject: suspect.subject,
                        received: suspect.receivedAt.map(Email.dayText),
                        attachments: suspect.attachmentNames,
                        reasons: suspect.reasons.map(\.detail)
                    )
                }
            )
        }
    }

    @Tool("decide")
    struct Decide {
        @JSONSchema
        public struct Input: HashableSource {
            public let account: String?
            /// trust or block (a sender or domain); record or dismiss (one message).
            public let verdict: String
            /// For trust/block: an address (sender) or a domain.
            public let value: String?
            /// For record/dismiss: the message's UID and mailbox (INBOX when absent).
            public let uid: Int?
            public let mailbox: String?
            /// Why, kept with the decision.
            public let note: String?

            public init(account: String? = nil, verdict: String, value: String? = nil, uid: Int? = nil, mailbox: String? = nil, note: String? = nil) {
                self.account = account
                self.verdict = verdict
                self.value = value
                self.uid = uid
                self.mailbox = mailbox
                self.note = note
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let verdict: String
            public let scope: String
            public let value: String
        }

        public static let purpose =
            "Record a review decision in the account's index: trust or block a sender or domain (future scoring follows it), or mark one message a genuine record or harmless. Changes nothing on the server. Trusting is approved by the owner."
        public static let risk: ActionRisk = .boundedmutate

        public init() {}

        /// Trust silences future warnings, so the owner approves it.
        public func preflight(_ input: Input, in context: CapabilityContext) async throws -> ToolPreflight {
            let decision = try await Self.decision(input, in: context)
            return ToolPreflight(
                tool: Self.definition.identifier,
                risk: decision.verdict == .trust ? .privileged : .boundedmutate,
                summary: "\(decision.verdict.rawValue) \(decision.scope.rawValue) \(decision.value)" + (input.note.map { " (\($0))" } ?? ""),
                access: .init(targets: [decision.value]),
                sideEffects: ["changes how mail review scores this \(decision.scope.rawValue)"],
                policyChecks: ["local_index_only"]
            )
        }

        public func call(_ input: Input, in context: CapabilityContext) async throws -> Output {
            let decision = try await Self.decision(input, in: context)
            let authorization = try await Email.authorization(in: context)
            let account = try authorization.runtime.account(input.account)
            try await Email.index(for: account, in: context).decide(decision)
            return Output(verdict: decision.verdict.rawValue, scope: decision.scope.rawValue, value: decision.value)
        }

        static func decision(
            _ input: Input,
            in context: CapabilityContext
        ) async throws -> MailDecision {
            let authorization = try await Email.authorization(in: context)
            try Email.requireWholeAccounts(authorization.runtime)
            let account = try authorization.runtime.account(input.account)
            try authorization.requireWholeAccount(.read, account: account)
            let verdict = try Email.choice(input.verdict, default: MailDecision.Verdict.dismiss, field: "verdict")
            switch verdict {
            case .trust, .block:
                guard let value = input.value.flatMap(Email.nonEmpty) else {
                    throw Email.Failure.invalidInput("\(verdict.rawValue) needs value: the sender address or the domain.")
                }
                return MailDecision(verdict, value.contains("@") ? .sender : .domain, value, note: input.note)
            case .record, .dismiss:
                guard let uid = input.uid else {
                    throw Email.Failure.invalidInput("\(verdict.rawValue) needs uid (and mailbox, INBOX when absent): the message.")
                }
                let mailbox = input.mailbox ?? "INBOX"
                let index = try Email.index(for: account, in: context)
                guard let messageID = try await index.messageID(IMAPUID(UInt32(uid)), in: mailbox) else {
                    throw Email.Failure.messageNotFound(uid: uid, mailbox: mailbox)
                }
                return MailDecision(verdict, .message, messageID, note: input.note)
            }
        }
    }

    @Tool("plan")
    struct Plan {
        @JSONSchema
        public struct Input: HashableSource {
            public let account: String?
            /// move, flag, unflag, label or unlabel.
            public let action: String
            /// The destination mailbox for move (created when missing), such as `Review/Suspicious`,
            /// `Records/2026` or `Pruned`; the flag or keyword (`$Suspicious`, `\Flagged`); or the Gmail label.
            public let value: String
            /// Why, as the owner will read it when approving.
            public let reason: String
            /// Pick the suspects mail_tool_suspicious would list.
            public let suspicious: Bool?
            /// With suspicious: the lowest score; and vendor domains known to be real.
            public let threshold: Int?
            public let trusted: [String]?
            /// Or pick by sender, domain or List-Id, narrowed by the fields below.
            public let sender: String?
            public let domain: String?
            public let list: String?
            /// Or pick these UIDs of `mailbox`.
            public let uids: [Int]?
            public let mailbox: String?
            public let older_than_days: Int?
            public let newer_than_days: Int?
            public let unread: Bool?

            public init(account: String? = nil, action: String, value: String, reason: String, suspicious: Bool? = nil, threshold: Int? = nil, trusted: [String]? = nil, sender: String? = nil, domain: String? = nil, list: String? = nil, uids: [Int]? = nil, mailbox: String? = nil, older_than_days: Int? = nil, newer_than_days: Int? = nil, unread: Bool? = nil) {
                self.account = account
                self.action = action
                self.value = value
                self.reason = reason
                self.suspicious = suspicious
                self.threshold = threshold
                self.trusted = trusted
                self.sender = sender
                self.domain = domain
                self.list = list
                self.uids = uids
                self.mailbox = mailbox
                self.older_than_days = older_than_days
                self.newer_than_days = newer_than_days
                self.unread = unread
            }
        }

        @JSONSchema
        public struct Sample: HashableResult {
            public let mailbox: String
            public let uid: Int
            public let from: String?
            public let subject: String?
            public let received: String?
        }

        @JSONSchema
        public struct Output: HashableResult {
            /// Pass to mail_tool_apply once the plan is right.
            public let plan: String
            public let summary: String
            public let count: Int
            public let samples: [Sample]
        }

        public static let purpose =
            "Propose one server change (move to a mailbox, add or remove a flag or keyword, Gmail label) for messages picked from the index: suspects, a sender, domain or list, or UIDs, narrowed by mailbox, age or unread. Stores the plan and shows samples; changes nothing until mail_tool_apply."
        public static let risk: ActionRisk = .boundedmutate

        public init() {}

        /// Only stores a proposal in the local index; the summary says what it picks.
        public func preflight(_ input: Input, in context: CapabilityContext) async throws -> ToolPreflight {
            let selection: String
            if input.suspicious == true {
                selection = "the suspects (score \(input.threshold ?? 50)+)"
            } else if let uids = input.uids, !uids.isEmpty {
                selection = "UIDs \(uids.map(String.init).joined(separator: ", ")) in \(input.mailbox ?? "?")"
            } else {
                selection = [input.sender, input.domain, input.list].compactMap { $0 }.joined(separator: ", ")
            }
            return ToolPreflight(
                tool: Self.definition.identifier,
                risk: Self.definition.risk,
                summary: "Propose \(input.action) \(input.value) for \(selection.isEmpty ? "a selection" : selection) on \(input.account ?? "the default account") (\(input.reason)). Stored only; nothing changes until mail_tool_apply.",
                sideEffects: ["stores a plan in the local index"],
                policyChecks: ["local_index_only"]
            )
        }

        public func call(_ input: Input, in context: CapabilityContext) async throws -> Output {
            let authorization = try await Email.authorization(in: context)
            let runtime = authorization.runtime
            try Email.requireWholeAccounts(runtime)
            let account = try runtime.account(input.account)
            try authorization.requireWholeAccount(.read, account: account)
            let index = try Email.index(for: account, in: context)

            let action: MailAction
            switch input.action.lowercased() {
            case "move": action = .move(to: input.value)
            case "flag": action = .addFlags([input.value])
            case "unflag": action = .removeFlags([input.value])
            case "label": action = .addLabels([input.value])
            case "unlabel": action = .removeLabels([input.value])
            default: throw Email.Failure.invalidInput("action must be move, flag, unflag, label or unlabel, not '\(input.action)'.")
            }
            guard let reason = Email.nonEmpty(input.reason) else {
                throw Email.Failure.missingReason
            }

            var filter = MailIndexFilter(mailbox: input.mailbox, sender: input.sender, domain: input.domain, listID: input.list)
            if let days = input.older_than_days {
                filter.receivedBefore = Date().addingTimeInterval(-Double(days) * 86_400)
            }
            if let days = input.newer_than_days {
                filter.receivedSince = Date().addingTimeInterval(-Double(days) * 86_400)
            }
            if input.unread == true {
                filter.unread = true
            }

            let targets: [MailPlan.Target]
            if input.suspicious == true {
                let policy = MailSuspicionPolicy(
                    trustedDomains: Set(input.trusted ?? []),
                    ownDomains: Email.ownDomains(runtime.accounts),
                    threshold: input.threshold ?? 50
                )
                targets = try await index.targets(try await index.suspicious(policy, filter: filter))
            } else if let uids = input.uids, !uids.isEmpty {
                guard input.mailbox != nil else {
                    throw Email.Failure.invalidInput("uids need mailbox: the mailbox they are in, as mail_tool_suspicious or mail_tool_search reported it (such as INBOX or INBOX.spam).")
                }
                let wanted = Set(uids.map { IMAPUID(UInt32($0)) })
                targets = try await index.targets(filter).filter { wanted.contains($0.uid) }
            } else if input.sender != nil || input.domain != nil || input.list != nil {
                targets = try await index.targets(filter)
            } else {
                throw Email.Failure.invalidInput("Pick messages with one of: suspicious: true, sender, domain, list, or uids with mailbox.")
            }
            guard !targets.isEmpty else {
                throw Email.Failure.invalidInput("No indexed message matches the selection; run mail_tool_index_sync if it is new, or widen the selection.")
            }

            let plan = MailPlan(steps: [.init(action, reason: reason, targets: targets)])
            try await index.save(plan)
            return Output(
                plan: plan.id,
                summary: plan.summary,
                count: plan.count,
                samples: try await index.previews(targets, limit: 10).map { preview in
                    Sample(
                        mailbox: preview.target.mailbox,
                        uid: Int(preview.target.uid.rawValue),
                        from: preview.fromAddress,
                        subject: preview.subject,
                        received: preview.receivedAt.map(Email.dayText)
                    )
                }
            )
        }
    }

    @Tool("plans")
    struct Plans {
        @JSONSchema
        public struct Input: HashableSource {
            public let account: String?
            /// One plan to show with its messages; the latest plans when absent.
            public let plan: String?

            public init(account: String? = nil, plan: String? = nil) {
                self.account = account
                self.plan = plan
            }
        }

        @JSONSchema
        public struct Entry: HashableResult {
            public let plan: String
            /// proposed, applied or undone.
            public let state: String
            public let summary: String
            public let count: Int
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let account: String
            public let plans: [Entry]
            /// With plan: its messages (up to 30).
            public let messages: [Plan.Sample]?
        }

        public static let purpose =
            "List an account's stored plans with their state (proposed, applied, undone), or show one plan's messages, to reuse a plan instead of making another."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: CapabilityContext) async throws -> Output {
            let authorization = try await Email.authorization(in: context)
            try Email.requireWholeAccounts(authorization.runtime)
            let account = try authorization.runtime.account(input.account)
            try authorization.requireWholeAccount(.read, account: account)
            let index = try Email.index(for: account, in: context)

            func entry(_ record: MailPlanRecord) -> Entry {
                Entry(
                    plan: record.plan.id,
                    state: record.undoneAt != nil ? "undone" : record.appliedAt != nil ? "applied" : "proposed",
                    summary: record.plan.summary,
                    count: record.plan.count
                )
            }
            if let id = input.plan.flatMap(Email.nonEmpty) {
                guard let record = try await index.plan(id) else {
                    throw Email.Failure.invalidInput("No plan \(id) for \(account.identifier); call mail_tool_plans without plan to list them.")
                }
                let previews = try await index.previews(record.plan.steps.flatMap(\.targets), limit: 30)
                return Output(
                    account: account.identifier,
                    plans: [entry(record)],
                    messages: previews.map { preview in
                        Plan.Sample(
                            mailbox: preview.target.mailbox,
                            uid: Int(preview.target.uid.rawValue),
                            from: preview.fromAddress,
                            subject: preview.subject,
                            received: preview.receivedAt.map(Email.dayText)
                        )
                    }
                )
            }
            return Output(account: account.identifier, plans: try await index.plans(limit: 20).map(entry), messages: nil)
        }
    }

    @Tool("apply")
    struct Apply {
        @JSONSchema
        public struct Input: HashableSource {
            public let account: String?
            /// The plan from mail_tool_plan.
            public let plan: String

            public init(account: String? = nil, plan: String) {
                self.account = account
                self.plan = plan
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let plan: String
            public let applied: Int
            /// Messages left alone, with why: changed or gone since indexing, or a renumbered mailbox.
            public let skipped: [String]
            public let touched: [String]
        }

        public static let purpose =
            "Apply a stored plan on the server after the owner approves it: every message is checked again (mailbox numbering, Message-ID) and skipped when it changed; results are journaled for mail_tool_undo and the index re-synced. Never deletes. Needs an organize grant on the account."
        public static let risk: ActionRisk = .privileged

        public init() {}

        public func preflight(_ input: Input, in context: CapabilityContext) async throws -> ToolPreflight {
            let (account, index, plan) = try await Self.load(input, in: context)
            return ToolPreflight(
                tool: Self.definition.identifier,
                risk: .privileged,
                summary: "Apply on \(account.identifier): \(plan.summary)",
                access: .init(targets: Array(Set(plan.steps.flatMap { $0.targets.map(\.mailbox) })).sorted()),
                estimates: .init(write: .init(count: plan.count)),
                preview: .init([
                    .report(try Email.planCard(plan, account: account.identifier, previews: try await index.previews(plan.steps.flatMap(\.targets), limit: 15)), title: "Plan"),
                ]),
                sideEffects: ["moves, flags or labels messages on the mail server, visible in every mail client", "reversible with mail_tool_undo"],
                policyChecks: ["organize_grant", "access_profile:\(try Email.runtime(in: context).access.name)"]
            )
        }

        public func call(_ input: Input, in context: CapabilityContext) async throws -> Output {
            let (account, index, plan) = try await Self.load(input, in: context)
            let report = try await Email.execute(plan, account: account, index: index, in: context)
            return Output(
                plan: plan.id,
                applied: report.applied,
                skipped: report.skipped.map { "\($0.target.mailbox):\($0.target.uid): \($0.reason)" },
                touched: report.touched
            )
        }

        static func load(
            _ input: Input,
            in context: CapabilityContext
        ) async throws -> (MailAccounts.Account, MailIndex, MailPlan) {
            let authorization = try await Email.authorization(in: context)
            try authorization.runtime.access.checkDrafting()
            let account = try authorization.runtime.account(input.account)
            try authorization.requireWholeAccount(.organize, account: account)
            let index = try Email.index(for: account, in: context)
            guard let record = try await index.plan(input.plan) else {
                throw Email.Failure.invalidInput("No plan \(input.plan) for this account; mail_tool_plans lists them.")
            }
            guard record.appliedAt == nil else {
                throw Email.Failure.invalidInput("Plan \(input.plan) was already applied; mail_tool_undo reverses it.")
            }
            return (account, index, record.plan)
        }
    }

    @Tool("undo")
    struct Undo {
        @JSONSchema
        public struct Input: HashableSource {
            public let account: String?
            /// An applied plan.
            public let plan: String

            public init(account: String? = nil, plan: String) {
                self.account = account
                self.plan = plan
            }
        }

        public typealias Output = Apply.Output

        public static let purpose =
            "Reverse an applied plan from its journal after the owner approves: moved messages go back, flags and labels come off, each checked like mail_tool_apply. Needs an organize grant on the account."
        public static let risk: ActionRisk = .privileged

        public init() {}

        public func preflight(_ input: Input, in context: CapabilityContext) async throws -> ToolPreflight {
            let (account, index, undo) = try await Self.load(input, in: context)
            return ToolPreflight(
                tool: Self.definition.identifier,
                risk: .privileged,
                summary: "Undo on \(account.identifier): \(undo.summary)",
                access: .init(targets: Array(Set(undo.steps.flatMap { $0.targets.map(\.mailbox) })).sorted()),
                estimates: .init(write: .init(count: undo.count)),
                preview: .init([
                    .report(try Email.planCard(undo, account: account.identifier, previews: try await index.previews(undo.steps.flatMap(\.targets), limit: 15)), title: "Undo"),
                ]),
                sideEffects: ["moves, flags or labels messages back on the mail server"],
                policyChecks: ["organize_grant"]
            )
        }

        public func call(_ input: Input, in context: CapabilityContext) async throws -> Output {
            let (account, index, undo) = try await Self.load(input, in: context)
            let report = try await Email.execute(undo, account: account, index: index, in: context)
            return Output(
                plan: undo.id,
                applied: report.applied,
                skipped: report.skipped.map { "\($0.target.mailbox):\($0.target.uid): \($0.reason)" },
                touched: report.touched
            )
        }

        static func load(
            _ input: Input,
            in context: CapabilityContext
        ) async throws -> (MailAccounts.Account, MailIndex, MailPlan) {
            let authorization = try await Email.authorization(in: context)
            try authorization.runtime.access.checkDrafting()
            let account = try authorization.runtime.account(input.account)
            try authorization.requireWholeAccount(.organize, account: account)
            let index = try Email.index(for: account, in: context)
            guard let record = try await index.plan(input.plan), record.appliedAt != nil, record.undoneAt == nil else {
                throw Email.Failure.invalidInput("Plan \(input.plan) is not an applied plan that can still be undone; mail_tool_plans shows each plan's state.")
            }
            let undo = try await index.undoPlan(for: input.plan)
            guard undo.count > 0 else {
                throw Email.Failure.invalidInput("Plan \(input.plan) changed nothing that can be reversed.")
            }
            return (account, index, undo)
        }
    }
}

extension Email {
    static func execute(
        _ plan: MailPlan,
        account: MailAccounts.Account,
        index: MailIndex,
        in context: CapabilityContext
    ) async throws -> MailPlanReport {
        let runtime = try Email.runtime(in: context)
        return try await runtime.imap(account).session { session in
            try await MailPlanExecutor(index: index, session: session).execute(plan)
        }
    }

    /// A raw-value choice, case-insensitive, with a message naming the options.
    static func choice<T: RawRepresentable & CaseIterable>(
        _ text: String?,
        default fallback: T,
        field: String
    ) throws -> T where T.RawValue == String {
        guard let text = text.flatMap(nonEmpty) else {
            return fallback
        }
        guard let value = T(rawValue: text.lowercased()) else {
            throw Failure.invalidInput("\(field) must be one of \(T.allCases.map(\.rawValue).joined(separator: ", ")), not '\(text)'.")
        }
        return value
    }
}
