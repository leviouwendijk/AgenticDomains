import Agentic
import AgenticMail
import Foundation
import IMAP
import Mail
import MailConnection
import MailFrame
import MailIndex
import Testing

/// A scripted IMAP server for building an index without the fake server's command set.
actor ScriptedIMAP: MailTransport {
    private var incoming: Data

    init(_ lines: [String]) {
        incoming = Data(lines.map { $0 + "\r\n" }.joined().utf8)
    }

    func write(_ data: Data) async throws {}

    func readLine() async throws -> String {
        guard let range = incoming.range(of: Data("\r\n".utf8)) else {
            throw MailConnectionError.connectionClosed
        }
        let line = incoming[incoming.startIndex..<range.lowerBound]
        incoming.removeSubrange(incoming.startIndex..<range.upperBound)
        return String(decoding: line, as: UTF8.self)
    }

    func read(count: Int) async throws -> Data {
        let bytes = Data(incoming.prefix(count))
        incoming.removeFirst(count)
        return bytes
    }

    func close() async {}

    func startTLS() async throws {}
}

enum OrganizeTests {
    /// An index of `work` with a fake invoice from a gmail stranger and a newsletter.
    static func indexed() async throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("agentic-mail-index-\(UUID().uuidString)", isDirectory: true)
        let pdf = "((\"text\" \"plain\" NIL NIL NIL \"7bit\" 100 3) (\"application\" \"pdf\" NIL NIL NIL \"base64\" 40000 NIL (\"attachment\" (\"filename\" \"Factuur 1.pdf\")) NIL NIL) \"mixed\")"
        let fields = "BODY[HEADER.FIELDS (LIST-ID LIST-UNSUBSCRIBE PRECEDENCE AUTO-SUBMITTED AUTHENTICATION-RESULTS RETURN-PATH)]"
        func fetch(_ sequence: Int, _ uid: Int, _ local: String, _ domain: String, _ subject: String, headers: String = "", structure: String) -> [String] {
            let block = headers + "\r\n"
            return [
                "* \(sequence) FETCH (UID \(uid) FLAGS () INTERNALDATE \"19-Nov-2026 10:00:00 +0100\" RFC822.SIZE 2000 ENVELOPE (\"Thu, 19 Nov 2026 10:00:00 +0100\" \"\(subject)\" ((NIL NIL \"\(local)\" \"\(domain)\")) NIL NIL ((NIL NIL \"alex\" \"practice.example\")) NIL NIL NIL \"<m\(uid)@\(domain)>\") \(fields) {\(block.utf8.count)}",
                block + " BODYSTRUCTURE \(structure))",
            ]
        }
        let text = "(\"text\" \"plain\" NIL NIL NIL \"7bit\" 100 3 NIL NIL NIL NIL)"
        var lines = ["* OK ready", "* CAPABILITY IMAP4rev1", "A1 OK done"]
        lines += ["* LIST (\\HasNoChildren) \"/\" \"INBOX\"", "A2 OK listed"]
        lines += ["* 2 EXISTS", "* OK [UIDVALIDITY 5] v", "* OK [UIDNEXT 3] n", "A3 OK [READ-ONLY] examined"]
        lines += ["* SEARCH 1 2", "A4 OK searched"]
        lines += fetch(1, 1, "sanne1234", "gmail.com", "Domeinregistratie voor 2027", structure: pdf)
        lines += fetch(2, 2, "news", "shop.example", "Deals", headers: "List-Id: <deals.shop.example>\r\nList-Unsubscribe: <mailto:u@shop.example>\r\n", structure: text)
        lines += ["A5 OK fetched"]

        let session = IMAPSession(transport: ScriptedIMAP(lines))
        try await session.start()
        let index = try MailIndex(url: Email.IndexLocation(directory: directory).url(account: "work"))
        _ = try await index.sync(session)
        return directory
    }

    static func context(
        _ directory: URL,
        level: Email.Level
    ) throws -> CapabilityContext {
        CapabilityContext(services: try CapabilityServices()
            .inserting(MailFixture.runtime(recorder: MailRecorder()))
            .inserting(Email.SessionAccess(grants: [Email.Grant(try MailSelector(parsing: "work"), level: level, reason: "test")]))
            .inserting(Email.IndexLocation(directory: directory)))
    }

    static func scanAndPlan() async throws {
        let directory = try await indexed()
        let context = try context(directory, level: .read)

        let suspects = try await Email.Tools.Suspicious().call(.init(account: "work"), in: context)
        try Expect.equal(suspects.suspects.map(\.uid), [1], "The free-mail invoice")
        try Expect.true(suspects.suspects[0].reasons.contains { $0.contains("gmail.com address") }, "With its reasons")

        let clutter = try await Email.Tools.Clutter().call(.init(account: "work", by: "list"), in: context)
        try Expect.equal(clutter.rows.map(\.key), ["deals.shop.example"], "Lists")

        let plan = try await Email.Tools.Plan().call(
            .init(account: "work", action: "move", value: "Review/Suspicious", reason: "fake invoice", suspicious: true),
            in: context
        )
        try Expect.equal(plan.count, 1, "One message")
        try Expect.equal(plan.samples.first?.subject, "Domeinregistratie voor 2027", "Sample shown")

        let listed = try await Email.Tools.Plans().call(.init(account: "work"), in: context)
        try Expect.equal(listed.plans.map(\.plan), [plan.plan], "Stored plans")
        try Expect.equal(listed.plans.first?.state, "proposed", "Not applied")
        let shown = try await Email.Tools.Plans().call(.init(account: "work", plan: plan.plan), in: context)
        try Expect.equal(shown.messages?.map(\.uid), [1], "A plan's messages")

        do {
            _ = try await Email.Tools.Plan().call(.init(account: "work", action: "move", value: "Pruned", reason: "x", uids: [1]), in: context)
            throw TestFlowAssertionFailure(label: "uids", message: "uids without a mailbox should be refused")
        } catch Email.Failure.invalidInput(let message) {
            try Expect.contains(message, "need mailbox", "Says what to add")
        }

        // Applying needs an organize grant, and the owner's approval of the plan.
        try await GrantTests.expectAccessRequired("apply with read") {
            _ = try await Email.Tools.Apply().preflight(.init(account: "work", plan: plan.plan), in: context)
        }
        let organizing = try Self.context(directory, level: .organize)
        let preflight = try await Email.Tools.Apply().preflight(.init(account: "work", plan: plan.plan), in: organizing)
        try Expect.equal(preflight.risk, .privileged, "Each plan is approved")
        try Expect.true(preflight.summary.contains("move to Review/Suspicious: 1 message"), "Summary: \(preflight.summary)")

        // Trusting silences warnings: approved by the owner; blocking is bounded.
        let trust = try await Email.Tools.Decide().preflight(.init(account: "work", verdict: "trust", value: "gmail.com"), in: context)
        try Expect.equal(trust.risk, .privileged, "Trust is approved")
        let block = try await Email.Tools.Decide().preflight(.init(account: "work", verdict: "block", value: "sanne1234@gmail.com"), in: context)
        try Expect.equal(block.risk, .boundedmutate, "Block is bounded")
    }

    static func mailboxLimitedGrantRefused() async throws {
        let directory = try await indexed()
        let context = CapabilityContext(services: try CapabilityServices()
            .inserting(MailFixture.runtime(recorder: MailRecorder()))
            .inserting(Email.SessionAccess(grants: [Email.Grant(try MailSelector(parsing: "work:INBOX"), level: .organize, reason: "test")]))
            .inserting(Email.IndexLocation(directory: directory)))
        try await GrantTests.expectAccessRequired("index needs the whole account") {
            _ = try await Email.Tools.Suspicious().call(.init(account: "work"), in: context)
        }
    }
}
