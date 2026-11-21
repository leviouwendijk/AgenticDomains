import Agentic
import DSL
import Foundation
import MailFrame
import MailIndex
import Reporting

public extension Email {
    /// Where account indexes live. Insert one into `ToolServices` to point the
    /// tools elsewhere; without one they use `~/.local/share/mail/index`, the
    /// same files as `email index`.
    struct IndexLocation: Sendable {
        public let directory: URL

        public init(directory: URL) {
            self.directory = directory
        }

        public func url(account: String) -> URL {
            directory.appendingPathComponent("\(account).sqlite")
        }
    }
}

extension Email {
    /// The account's index; it exists once `mail_tool_index_sync` (or `email index`) ran.
    static func index(
        for account: MailAccounts.Account,
        in context: ToolContext,
        creating: Bool = false
    ) throws -> MailIndex {
        let url = (try? context.require(IndexLocation.self))?.url(account: account.identifier)
            ?? MailIndex.defaultURL(account: account.identifier)
        guard creating || MailIndex.exists(at: url) else {
            throw Failure.invalidInput("\(account.identifier) has no index yet; run mail_tool_index_sync first.")
        }
        return try MailIndex(url: url)
    }

    /// The index answers for whole accounts, so a profile limited to some
    /// mailboxes cannot use it.
    static func requireWholeAccounts(
        _ runtime: Runtime
    ) throws {
        if runtime.access.restrictsMailboxes {
            throw Failure.invalidInput("The access profile \(runtime.access.name) limits mailboxes, and the index covers whole accounts; use mail_tool_search instead.")
        }
    }

    /// `yyyy-MM-dd` in the current zone.
    static func dayText(
        _ date: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Domains of every configured identity, except free-mail providers.
    static func ownDomains(
        _ accounts: MailAccounts
    ) -> Set<String> {
        Set(
            accounts.accounts
                .flatMap(\.identities)
                .map { String($0.address.address.domain).lowercased() }
                .filter { !MailSuspicionPolicy.freemailDomains.contains($0) }
        )
    }

    /// What a plan changes, as the owner approves it.
    static func planCard(
        _ plan: MailPlan,
        account: String,
        previews: [MailTargetPreview]
    ) throws -> ReportDocument {
        var facts: [ReportBlock.Facts.Fact] = [.init("account", account), .init("plan", plan.id)]
        for step in plan.steps {
            facts.append(.init(step.action.description, "\(step.targets.count) message\(step.targets.count == 1 ? "" : "s") (\(step.reason))"))
        }
        let lines = previews.map { preview in
            StructuredContent.paragraph([.text(
                "\(preview.target.mailbox):\(preview.target.uid)  \(preview.fromAddress ?? "?")  \(preview.subject ?? "(no subject)")"
            )])
        }
        return try ReportDocument(
            title: "Mail plan \(plan.id)",
            datasets: [],
            blocks: [.facts(.init(facts: facts))] + (lines.isEmpty ? [] : [.narrative(.collection(lines))])
        )
    }
}
