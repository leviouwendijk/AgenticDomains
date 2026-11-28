import Agentic
import AgenticMail
import Foundation
import MailFrame
import Testing

enum GrantTests {
    static func expectAccessRequired(
        _ label: String,
        _ operation: () async throws -> Void
    ) async throws {
        do {
            try await operation()
        } catch Email.Failure.accessRequired {
            return
        }
        throw TestFlowAssertionFailure(label: label, message: "should need a grant")
    }

    static func nothingByDefault() async throws {
        let recorder = MailRecorder()
        let context = try EmailTests.context(recorder, grants: [])

        let accounts = try await Email.Tools.ListAccounts().call(.init(), in: context)
        try Expect.equal(accounts.groups, ["practice"], "Groups")
        try Expect.equal(Set(accounts.accounts.map(\.granted)), ["none"], "Nothing granted")
        try Expect.isEmpty(accounts.grants, "No grants")

        try await expectAccessRequired("Search") { _ = try await Email.Tools.Search().call(.init(), in: context) }
        try await expectAccessRequired("Mailboxes") { _ = try await Email.Tools.ListMailboxes().call(.init(), in: context) }
        try await expectAccessRequired("Read") { _ = try await Email.Tools.Read().call(.init(uid: 42), in: context) }
        try await expectAccessRequired("Draft") {
            _ = try await Email.Tools.SaveDraft().call(.init(to: ["jan@example.org"], subject: "x", body: "y"), in: context)
        }
        // Without a grant, every send is the owner's to approve, even where the account allows sending.
        let send = { (account: String) in Email.Composition(account: account, to: ["jan@example.org"], subject: "x", body: "y") }
        try Expect.equal(try await Email.Tools.Send().preflight(send("team"), in: context).risk, .privileged, "allowed still reviewed without a grant")
        try Expect.equal(try await Email.Tools.Send().preflight(send("work"), in: context).risk, .privileged, "confirm reviewed")
        try Expect.equal(try await Email.Tools.Send().preflight(send("personal"), in: context).risk, .forbidden, "drafts never sends")
        try Expect.true(await recorder.imapCommands.filter { !$0.hasPrefix("CAPABILITY") && !$0.hasPrefix("AUTHENTICATE") && !$0.hasPrefix("LOGOUT") }.isEmpty, "No mailbox touched")

        // Once the owner approves the message, it sends without any grant.
        let sent = try await Email.Tools.Send().call(send("work"), in: context)
        try Expect.equal(sent.accepted, ["jan@example.org"], "Approved send delivers without a grant")
        do {
            _ = try await Email.Tools.Send().call(.init(account: "work", body: "y", reply_to_uid: 42), in: context)
            throw TestFlowAssertionFailure(label: "reply", message: "a reply must not read the original without a grant")
        } catch Email.Failure.accessRequired {
        }

        do {
            _ = try await Email.Tools.Search().call(.init(), in: CapabilityContext(services: try CapabilityServices().inserting(MailFixture.runtime(recorder: recorder))))
            throw TestFlowAssertionFailure(label: "no store", message: "should fail")
        } catch Email.Failure.accessNotProvided {
        }
    }

    static func request() async throws {
        let context = try EmailTests.context(MailRecorder(), grants: [])
        let input = Email.Tools.RequestAccess.Input(targets: ["practice:@junk"], reason: "Find misfiled client mail")

        let preflight = try await Email.Tools.RequestAccess().preflight(input, in: context)
        try Expect.equal(preflight.risk, .privileged, "Always reviewed")
        try Expect.contains(preflight.summary, "read practice:@junk", "Shows the grant")
        try Expect.contains(preflight.summary, "work, team", "Shows the accounts it opens")
        try Expect.contains(preflight.summary, "Find misfiled client mail", "Shows the reason")

        let output = try await Email.Tools.RequestAccess().call(input, in: context)
        try Expect.equal(output.session, ["read practice:@junk"], "Granted for the session")
        let accounts = try await Email.Tools.ListAccounts().call(.init(), in: context)
        try Expect.equal(accounts.accounts.map(\.granted), ["read", "read", "none"], "Per account")

        try await Expect.throwsError("No reason") {
            _ = try await Email.Tools.RequestAccess().call(.init(targets: ["work"], reason: " "), in: context)
        }
        try await Expect.throwsError("Unknown target") {
            _ = try await Email.Tools.RequestAccess().call(.init(targets: ["nobody"], reason: "x"), in: context)
        }

        let profile = try await Email.Tools.RequestAccess().call(.init(profile: "clientDesk", level: "draft", reason: "Answer clients"), in: context)
        try Expect.equal(profile.granted, ["draft work:INBOX", "draft work:INBOX/Klanten/*"], "A profile becomes grants")
    }

    static func roleAcrossGroup() async throws {
        let recorder = MailRecorder()
        let context = try EmailTests.context(recorder, grants: [Email.Grant(try MailSelector(parsing: "practice:@junk"), level: .read, reason: "test")])

        let found = try await Email.Tools.Search().call(.init(targets: ["practice:@junk"], unread: true), in: context)
        try Expect.equal(found.searched, ["work:Spam", "team:Spam"], "Each account's Junk, by role")
        try Expect.equal(found.total_matches, 4, "Matches across both")
        try Expect.equal(Set(found.messages.map(\.account)), ["work", "team"], "Results carry their account")

        let mailboxes = try await Email.Tools.ListMailboxes().call(.init(account: "work"), in: context)
        try Expect.equal(mailboxes.mailboxes.map(\.name), ["Spam"], "Only granted mailboxes are listed")

        try await expectAccessRequired("INBOX not granted") {
            _ = try await Email.Tools.Search().call(.init(targets: ["practice"]), in: context)
        }
        try await expectAccessRequired("Other account") {
            _ = try await Email.Tools.Search().call(.init(targets: ["personal:@junk"]), in: context)
        }
        try await expectAccessRequired("Drafting needs draft") {
            _ = try await Email.Tools.SaveDraft().call(.init(account: "work", to: ["jan@example.org"], subject: "x", body: "y"), in: context)
        }
    }

    static func mailboxLevel() async throws {
        let recorder = MailRecorder()
        let context = try EmailTests.context(recorder, grants: [Email.Grant(try MailSelector(parsing: "work:INBOX/Klanten/*"), level: .read, reason: "test")])

        let found = try await Email.Tools.Search().call(.init(account: "work", mailbox: "INBOX/Klanten"), in: context)
        try Expect.equal(found.searched, ["work:INBOX/Klanten"], "The granted folder")
        try await expectAccessRequired("Parent INBOX") {
            _ = try await Email.Tools.Read().call(.init(account: "work", mailbox: "INBOX", uid: 42), in: context)
        }
        try Expect.false(await recorder.imapCommands.contains("EXAMINE \"INBOX\""), "Never opened INBOX")
    }
}
