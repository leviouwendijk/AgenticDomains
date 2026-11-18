import Agentic
import AgenticMail
import Foundation
import IMAP
import Mail
import MailFrame
import Testing

private enum AgenticMailTestingFailure: Error {
    case failed
}

@main
struct AgenticMailTestingMain {
    static func main() async throws {
        let reporter = PlainTextTestReporter(
            output: ClosureTestTextOutput { text in
                FileHandle.standardOutput.write(Data(text.utf8))
            }
        )
        let result = await TestRunner.run(
            AgenticMailTestSuite.suite,
            sink: reporter
        )
        if result.isFailure {
            throw AgenticMailTestingFailure.failed
        }
    }
}

enum AgenticMailTestSuite {
    static let suite = TestSuite(
        "agentic-mail",
        title: "AgenticMail"
    ) {
        Test("accounts-list-identities-and-policy") {
            try await EmailTests.accounts()
        }
        Test("mailboxes-with-roles-and-counts") {
            try await EmailTests.mailboxes()
        }
        Test("search-builds-server-query-newest-first") {
            try await EmailTests.search()
        }
        Test("read-reduces-html-without-marking-seen") {
            try await EmailTests.read()
        }
        Test("draft-reply-threads-and-saves-to-drafts") {
            try await EmailTests.draftReply()
        }
        Test("send-risk-follows-account-policy") {
            try await EmailTests.sendPolicy()
        }
        Test("send-delivers-and-saves-sent-copy") {
            try await EmailTests.send()
        }
        Test("gmail-query-refused-on-other-servers") {
            try await EmailTests.gmailElsewhere()
        }
        Test("access-profile-limits-every-tool") {
            try await EmailTests.scoped()
        }
        Test("unconfigured-mail-says-why") {
            try await EmailTests.unconfigured()
        }
    }
}

enum EmailTests {
    static func context(
        _ recorder: MailRecorder
    ) throws -> ToolContext {
        ToolContext(services: try ToolServices().inserting(MailFixture.runtime(recorder: recorder)))
    }

    static func accounts() async throws {
        let output = try await Email.Tools.ListAccounts().call(.init(), in: try context(MailRecorder()))
        try Expect.equal(output.accounts.map(\.account), ["work", "team", "personal"], "Accounts in order")
        try Expect.true(output.accounts[0].is_default, "First is default")
        try Expect.equal(output.accounts[0].identities.map(\.address), ["alex@practice.example", "info@practice.example"], "Identities")
        try Expect.equal(output.accounts.map(\.sending), ["confirm", "allowed", "drafts"], "Policies")
        try Expect.false(output.accounts[2].can_send, "IMAP-only account cannot send")
    }

    static func mailboxes() async throws {
        let output = try await Email.Tools.ListMailboxes().call(.init(counts: true), in: try context(MailRecorder()))
        try Expect.equal(output.mailboxes.map(\.name), ["INBOX", "INBOX/Klanten", "Concepten", "Verzonden", "Archief"], "Folders and subfolders")
        try Expect.equal(output.mailboxes.map(\.role), [nil, nil, "drafts", "sent", nil], "Roles from SPECIAL-USE")
        try Expect.equal(output.mailboxes[0].unread, 2, "Unread count")
        try Expect.false(output.mailboxes[4].selectable, "Noselect folder")
        try Expect.isNil(output.mailboxes[4].total, "No count for a folder that cannot be selected")
    }

    static func search() async throws {
        let recorder = MailRecorder()
        let output = try await Email.Tools.Search().call(
            .init(mailbox: "INBOX/Klanten", unread: true, from: "jan", since: "2026-11-01"),
            in: try context(recorder)
        )
        try Expect.equal(output.total_matches, 2, "Matches")
        try Expect.equal(output.messages.map(\.uid), [42, 40], "Newest first")
        try Expect.equal(output.messages[0].from, ["Jan de Vries <jan@example.org>"], "Sender")
        try Expect.true(output.messages[0].unread, "Unread flag")

        let commands = await recorder.imapCommands
        try Expect.true(commands.contains("EXAMINE \"INBOX/Klanten\""), "Read-only select of the subfolder")
        try Expect.true(commands.contains("UID SEARCH UNSEEN FROM jan SINCE 1-Nov-2026"), "Server-side query: \(commands)")
    }

    static func read() async throws {
        let recorder = MailRecorder()
        let output = try await Email.Tools.Read().call(.init(uid: 42), in: try context(recorder))
        try Expect.equal(output.subject, "Afspraak volgende week", "Subject")
        try Expect.equal(output.body, "Kan Rex dinsdag om 10:00?", "HTML reduced to text")
        try Expect.true(await recorder.imapCommands.contains("UID FETCH 42 (UID BODY.PEEK[])"), "PEEK keeps it unread")
    }

    static func draftReply() async throws {
        let recorder = MailRecorder()
        let output = try await Email.Tools.SaveDraft().call(
            .init(body: "Dinsdag 10:00 past, tot dan.", reply_to_uid: 42),
            in: try context(recorder)
        )
        try Expect.equal(output.folder, "Concepten", "Drafts folder from SPECIAL-USE")
        try Expect.equal(output.uid, 501, "APPENDUID")
        try Expect.equal(output.to, ["Jan de Vries <jan@example.org>"], "Reply goes to the sender")
        try Expect.equal(output.subject, "Re: Afspraak volgende week", "Reply subject")

        let appended = try Expect.notNil(await recorder.appended.first, "Appended draft")
        try Expect.equal(appended.flags, "(\\Draft \\Seen)", "Draft flags")
        try Expect.contains(appended.message, "In-Reply-To: <orig-1@example.org>", "Threaded")
        try Expect.contains(appended.message, "--=20\r\nAlex\r\nPractice", "Signature after the -- delimiter")
        try Expect.true(await recorder.smtpCommands.isEmpty, "Nothing sent")
    }

    static func sendPolicy() async throws {
        let context = try context(MailRecorder())
        let message = { (account: String) in
            Email.Composition(account: account, to: ["jan@example.org"], subject: "Hoi", body: "Tot morgen.")
        }
        try Expect.equal(try await Email.Tools.Send().preflight(message("work"), in: context).risk, .privileged, "confirm needs review")
        try Expect.equal(try await Email.Tools.Send().preflight(message("team"), in: context).risk, .boundedmutate, "allowed is bounded")
        try Expect.equal(try await Email.Tools.Send().preflight(message("personal"), in: context).risk, .forbidden, "drafts forbids")

        do {
            _ = try await Email.Tools.Send().call(message("personal"), in: context)
            throw TestFlowAssertionFailure(label: "send", message: "drafts-only account must not send")
        } catch Email.Failure.sendingNotAllowed {
        }
    }

    static func send() async throws {
        let recorder = MailRecorder()
        let output = try await Email.Tools.Send().call(
            .init(account: "team", to: ["Jan <jan@example.org>", "nobody@example.org"], subject: "Bevestiging", body: "Dinsdag 10:00."),
            in: try context(recorder)
        )
        try Expect.equal(output.accepted, ["jan@example.org"], "Accepted")
        try Expect.equal(output.rejected.count, 1, "Rejected recipient reported")
        try Expect.equal(output.sent_copy, "Verzonden", "Copy in Sent")

        let delivered = await recorder.delivered.joined()
        let copy = try Expect.notNil(await recorder.appended.first, "Sent copy")
        let id = try Expect.notNil(
            delivered.split(separator: "\r\n").first { $0.hasPrefix("Message-ID:") },
            "Delivered Message-ID"
        )
        try Expect.contains(copy.message, String(id), "Sent copy is the delivered message")
        try Expect.equal(copy.flags, "(\\Seen)", "Sent copy marked seen")
    }

    static func gmailElsewhere() async throws {
        let recorder = MailRecorder()
        let plain = try await Email.Tools.Search().call(.init(unread: true), in: try context(recorder))
        try Expect.isNil(plain.messages.first?.thread_id, "No thread IDs off Gmail")
        do {
            _ = try await Email.Tools.Search().call(.init(gmail_query: "has:attachment"), in: try context(recorder))
            throw TestFlowAssertionFailure(label: "gmail", message: "should be refused")
        } catch IMAPError.unsupported(let capability) {
            try Expect.equal(capability, "X-GM-EXT-1", "Says Gmail is required")
        }
        try Expect.false(await recorder.imapCommands.contains { $0.contains("X-GM-RAW") }, "Never sent")
    }

    static func scoped() async throws {
        let recorder = MailRecorder()
        let context = ToolContext(services: try ToolServices()
            .inserting(MailFixture.runtime(recorder: recorder))
            .inserting(Email.Scope("clientDesk")))

        let accounts = try await Email.Tools.ListAccounts().call(.init(), in: context)
        try Expect.equal(accounts.access, "clientDesk", "Reports the profile")
        try Expect.equal(accounts.accounts.map(\.account), ["work"], "Only the profile's account")
        try Expect.equal(accounts.accounts[0].identities.map(\.address), ["info@practice.example"], "Only its identity")
        try Expect.equal(accounts.accounts[0].sending, "drafts", "Tightened to drafts")
        try Expect.false(accounts.accounts[0].can_send, "Cannot send")

        let mailboxes = try await Email.Tools.ListMailboxes().call(.init(), in: context)
        try Expect.equal(mailboxes.mailboxes.map(\.name), ["INBOX", "INBOX/Klanten"], "Only its mailboxes")

        try await expectRefused("Other account") {
            _ = try await Email.Tools.Search().call(.init(account: "team"), in: context)
        }
        try await expectRefused("Other mailbox") {
            _ = try await Email.Tools.Read().call(.init(mailbox: "Concepten", uid: 42), in: context)
        }
        try await expectRefused("Gmail syntax under a mailbox limit") {
            _ = try await Email.Tools.Search().call(.init(gmail_query: "is:starred"), in: context)
        }
        try await expectRefused("Other identity") {
            _ = try await Email.Tools.SaveDraft().call(.init(from: "alex@practice.example", to: ["jan@example.org"], subject: "x", body: "y"), in: context)
        }

        let send = Email.Composition(to: ["jan@example.org"], subject: "Hoi", body: "Tot morgen.")
        try Expect.equal(try await Email.Tools.Send().preflight(send, in: context).risk, .forbidden, "Sending forbidden by the profile")
        try await expectRefused("Send") {
            _ = try await Email.Tools.Send().call(send, in: context)
        }

        let draft = try await Email.Tools.SaveDraft().call(.init(to: ["jan@example.org"], subject: "Hoi", body: "Tot morgen."), in: context)
        try Expect.equal(draft.from, "info@practice.example", "Drafts as the profile's identity")
        try Expect.true(await recorder.smtpCommands.isEmpty, "Nothing sent")
        try Expect.false(await recorder.imapCommands.contains { $0.contains("Concepten") && $0.hasPrefix("EXAMINE") }, "Never opened a refused mailbox")
    }

    static func expectRefused(
        _ label: String,
        _ operation: () async throws -> Void
    ) async throws {
        do {
            try await operation()
        } catch is MailAccess.Failure {
            return
        } catch Email.Failure.sendingNotAllowed {
            return
        }
        throw TestFlowAssertionFailure(label: label, message: "the access profile should refuse this")
    }

    static func unconfigured() async throws {
        let empty = FileManager.default.temporaryDirectory.appendingPathComponent("agentic-mail-\(UUID().uuidString)")
        let missing = ToolContext(services: try ToolServices().inserting(
            MailConfigurationStore(directory: empty)
        ))
        do {
            _ = try await Email.Tools.ListAccounts().call(.init(), in: missing)
            throw TestFlowAssertionFailure(label: "missing", message: "should fail")
        } catch let failure as Email.Failure {
            try Expect.contains(failure.localizedDescription, "no .frame file in \(empty.path)", "Says where configuration is expected")
            try Expect.contains(failure.localizedDescription, "email example", "Points to the email CLI")
        }
    }
}
