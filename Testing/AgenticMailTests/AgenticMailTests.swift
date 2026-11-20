import Agentic
import AgenticMail
import Errors
import Foundation
import IMAP
import Mail
import MailFrame
import Reporting
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
        Test("no-grant-reads-nothing") {
            try await GrantTests.nothingByDefault()
        }
        Test("request-access-is-reviewed-and-grants") {
            try await GrantTests.request()
        }
        Test("role-selector-across-a-group") {
            try await GrantTests.roleAcrossGroup()
        }
        Test("mailbox-level-grant") {
            try await GrantTests.mailboxLevel()
        }
        Test("unconfigured-mail-says-why") {
            try await EmailTests.unconfigured()
        }
        Test("save-attachment-into-exports") {
            try await EmailTests.saveAttachment()
        }
        Test("index-scan-and-plan-need-organize-to-apply") {
            try await OrganizeTests.scanAndPlan()
        }
        Test("index-refuses-mailbox-limited-grant") {
            try await OrganizeTests.mailboxLimitedGrantRefused()
        }
        Test("send-html-with-attachment") {
            try await EmailTests.sendHTMLWithAttachment()
        }
    }
}

enum EmailTests {
    /// A session granted draft access to everything, for tests of the tools themselves.
    static func context(
        _ recorder: MailRecorder
    ) throws -> ToolContext {
        try context(recorder, grants: [Email.Grant(try MailSelector(parsing: "*"), level: .draft, reason: "test")])
    }

    static func context(
        _ recorder: MailRecorder,
        grants: [Email.Grant]
    ) throws -> ToolContext {
        ToolContext(services: try ToolServices()
            .inserting(MailFixture.runtime(recorder: recorder))
            .inserting(Email.SessionAccess(grants: grants)))
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
        try Expect.equal(output.mailboxes.map(\.name), ["INBOX", "INBOX/Klanten", "Concepten", "Verzonden", "Spam", "Archief"], "Folders and subfolders")
        try Expect.equal(output.mailboxes.map(\.role), ["inbox", nil, "drafts", "sent", "junk", nil], "Roles from SPECIAL-USE")
        try Expect.equal(output.mailboxes[0].unread, 2, "Unread count")
        try Expect.false(output.mailboxes[5].selectable, "Noselect folder")
        try Expect.isNil(output.mailboxes[5].total, "No count for a folder that cannot be selected")
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

        let addressed = MailRecorder()
        let either = try await Email.Tools.Search().call(.init(addressed: "jan"), in: try context(addressed))
        try Expect.true(await addressed.imapCommands.contains("UID SEARCH OR TO jan CC jan"), "To or Cc: \(await addressed.imapCommands)")
        try Expect.equal(either.messages.first?.cc, [], "Cc listed with each result")
    }

    static func read() async throws {
        let recorder = MailRecorder()
        let output = try await Email.Tools.Read().call(.init(uid: 42), in: try context(recorder))
        try Expect.equal(output.subject, "Afspraak volgende week", "Subject")
        try Expect.equal(output.body, "Kan Rex dinsdag om 10:00?", "HTML reduced to text")
        try Expect.true(await recorder.imapCommands.contains("UID FETCH 42 (UID BODY.PEEK[])"), "PEEK keeps it unread")
    }

    static func sendHTMLWithAttachment() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mail-attach-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let pdf = MailAttachment(filename: "offerte.pdf", data: Data("%PDF-1.4".utf8))
        let file = try pdf.save(in: root, index: 0)

        let recorder = MailRecorder()
        let context = ToolContext(services: try ToolServices()
            .inserting(MailFixture.runtime(recorder: recorder))
            .inserting(Email.SessionAccess())
            .inserting(Email.Downloads(directory: root)))
        let input = Email.Composition(
            account: "team",
            to: ["jan@example.org"],
            bcc: ["boekhouding@example.org"],
            subject: "Offerte",
            html: "<p style=\"color:#333\">Hoi Jan,</p><p>Zie de <b>offerte</b>.</p>",
            attachments: [file.path]
        )

        let preflight = try await Email.Tools.Send().preflight(input, in: context)
        try Expect.contains(preflight.summary, "attaching offerte.pdf", "Approval names the attachment")
        guard let section = preflight.preview.sections.first,
              case .report(let card) = section.content else {
            throw TestFlowAssertionFailure(label: "message card", message: "Send previews a message card")
        }
        let shown = ReportMarkdown.render(card)
        try Expect.equal(section.title, "Message", "The approval menu names the preview")
        try Expect.contains(shown, "Hoi Jan,", "Preview reads the HTML as text")
        try Expect.contains(shown, "**bcc**: boekhouding@example.org", "Headers on the card")

        _ = try await Email.Tools.Send().call(input, in: context)
        let delivered = await recorder.delivered.joined()
        try Expect.contains(delivered, "multipart/alternative", "HTML with a text version")
        try Expect.contains(delivered, "Content-Type: application/pdf", "PDF type from the extension")
        try Expect.contains(delivered, "filename=\"offerte.pdf\"", "Attachment name")
        try Expect.false(delivered.contains("Bcc:"), "Delivered without Bcc")
        let copy = try Expect.notNil(await recorder.appended.first, "Sent copy")
        try Expect.contains(copy.message, "Bcc: boekhouding@example.org", "Sent copy records Bcc")

        do {
            _ = try await Email.Tools.Send().preflight(.init(account: "team", to: ["jan@example.org"], subject: "x", body: "y", attachments: ["/etc/hosts"]), in: context)
            throw TestFlowAssertionFailure(label: "outside", message: "a file outside the workspace must be refused")
        } catch Email.Failure.attachmentOutside {
        }
        do {
            _ = try await Email.Tools.Send().preflight(.init(account: "team", to: ["jan@example.org"], subject: "x"), in: context)
            _ = try await Email.Tools.Send().call(.init(account: "team", to: ["jan@example.org"], subject: "x"), in: context)
            throw TestFlowAssertionFailure(label: "body", message: "a message without a body must be refused")
        } catch Email.Failure.missingBody {
        }
    }

    static func saveAttachment() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mail-downloads-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = MailRecorder()
        let context = ToolContext(services: try ToolServices()
            .inserting(MailFixture.runtime(recorder: recorder))
            .inserting(Email.SessionAccess(grants: [Email.Grant(try MailSelector(parsing: "*"), level: .read, reason: "test")]))
            .inserting(Email.Downloads(directory: root)))

        let preflight = try await Email.Tools.SaveAttachment().preflight(.init(uid: 43), in: context)
        try Expect.equal(preflight.risk, .boundedmutate, "Writing files is bounded")
        try Expect.contains(preflight.summary, "work/INBOX-43", "Names the destination")

        let output = try await Email.Tools.SaveAttachment().call(.init(uid: 43), in: context)
        let saved = try Expect.notNil(output.saved.first, "Saved one file")
        try Expect.equal(saved.path, root.appendingPathComponent("work/INBOX-43/factuur.pdf").standardizedFileURL.path, "Inside the message's folder, sender path dropped")
        try Expect.equal(saved.bytes, 8, "Decoded content")
        try Expect.true(await recorder.imapCommands.contains("UID FETCH 43 (UID BODY.PEEK[])"), "PEEK keeps it unread")

        let again = try await Email.Tools.SaveAttachment().call(.init(uid: 43), in: context)
        try Expect.true(again.saved.first?.path.hasSuffix("factuur (2).pdf") ?? false, "Never overwrites")

        do {
            _ = try await Email.Tools.SaveAttachment().call(.init(uid: 43, filenames: ["other.pdf"]), in: context)
            throw TestFlowAssertionFailure(label: "unknown", message: "an unknown filename should be refused")
        } catch Email.Failure.unknownAttachment(let name, _) {
            try Expect.equal(name, "other.pdf", "Names the missing attachment")
        }
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
            .inserting(Email.Scope("clientDesk"))
            .inserting(Email.SessionAccess(grants: [Email.Grant(try MailSelector(parsing: "*:*"), level: .draft, reason: "test")])))

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
            try Expect.contains(failure.explanation, "no .frame file in \(empty.path)", "Says where configuration is expected")
            try Expect.contains(failure.explanation, "email example", "Points to the email CLI")
            try Expect.equal(failure.errorIdentity.raw, "agentic_mail.configuration_missing", "Has a stable code")
            try Expect.equal(failure.errorDisposition, .requires_configuration, "Says configuration is what's missing")
            try Expect.contains(
                failure.errorPresentation.recoverySuggestion ?? "",
                "email example",
                "The fix is the suggestion, not the message"
            )
        }

        let denied = Email.Failure.accessRequired(level: .organize, target: "leads:@junk")
        try Expect.equal(denied.errorDisposition, .requires_access, "Missing access asks for access")
        try Expect.contains(
            denied.errorPresentation.recoverySuggestion ?? "",
            "mail_request_access",
            "Names the tool that asks for access"
        )
    }
}
