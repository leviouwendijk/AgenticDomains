import AgenticMail
import Foundation
import Mail
import MailConnection
import MailFrame

/// What the fake servers saw, for assertions.
actor MailRecorder {
    private(set) var imapCommands: [String] = []
    private(set) var appended: [(mailbox: String, flags: String, message: String)] = []
    private(set) var smtpCommands: [String] = []
    private(set) var delivered: [String] = []

    func imap(_ command: String) { imapCommands.append(command) }
    func append(_ mailbox: String, _ flags: String, _ message: String) { appended.append((mailbox, flags, message)) }
    func smtp(_ command: String) { smtpCommands.append(command) }
    func deliver(_ message: String) { delivered.append(message) }
}

enum MailFixture {
    static let original = """
        From: Jan de Vries <jan@example.org>\r
        To: Alex <alex@practice.example>\r
        Subject: Afspraak volgende week\r
        Message-ID: <orig-1@example.org>\r
        Date: Tue, 17 Nov 2026 09:30:00 +0100\r
        Content-Type: text/html; charset=utf-8\r
        \r
        <p>Kan Rex dinsdag om 10:00?</p>\r

        """

    static let frame = """
        import Mail;

        let host: Provider = .{
            .smtp = .{ .host = "smtp.test" },
            .imap = .{ .host = "imap.test" },
        };

        let work: Account = .{
            .provider = host,
            .username = "alex@practice.example",
            .password = .{ .env = "MAIL_WORK" },
            .identities = [
                .{ .address = "alex@practice.example", .name = "Alex", .signature = .{ .text = "Alex\\nPractice" } },
                .{ .address = "info@practice.example" },
            ],
            .sending = .confirm,
        };

        let team: Account = .{
            .provider = host,
            .username = "team@practice.example",
            .password = .{ .env = "MAIL_TEAM" },
            .identities = [.{ .address = "team@practice.example" }],
            .sending = .allowed,
        };

        let personal: Account = .{
            .provider = .{ .imap = .{ .host = "imap.test" } },
            .username = "me@example.net",
            .password = .{ .env = "MAIL_PERSONAL" },
            .identities = [.{ .address = "me@example.net" }],
        };

        let clientDesk: Access = .{
            .accounts = [work],
            .mailboxes = ["INBOX", "INBOX/Klanten/*"],
            .identities = ["info@practice.example"],
            .send = false,
        };
        """

    static func runtime(
        recorder: MailRecorder
    ) throws -> Email.Runtime {
        let accounts = try MailAccounts(
            source: frame,
            environment: ["MAIL_WORK": "w", "MAIL_TEAM": "t", "MAIL_PERSONAL": "p"]
        )
        return Email.Runtime(accounts: accounts) { server in
            server.port == 993
                ? FakeIMAPServer(recorder: recorder) as any MailTransport
                : FakeSMTPServer(recorder: recorder)
        }
    }
}

/// Answers IMAP commands by name with a small fixed mailbox.
actor FakeIMAPServer: MailTransport {
    private let recorder: MailRecorder
    private var output = Data("* OK fake ready\r\n".utf8)
    private var pendingAppend: (tag: String, mailbox: String, flags: String, count: Int)?
    private var literal = Data()

    init(recorder: MailRecorder) {
        self.recorder = recorder
    }

    func write(_ data: Data) async throws {
        if let pending = pendingAppend {
            literal.append(data)
            guard literal.count >= pending.count + 2 else { return }
            await recorder.append(pending.mailbox, pending.flags, String(decoding: literal.prefix(pending.count), as: UTF8.self))
            respond("\(pending.tag) OK [APPENDUID 7 501] APPEND completed")
            pendingAppend = nil
            literal = Data()
            return
        }

        let line = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines)
        let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
        let tag = parts[0]
        let command = parts.count > 1 ? parts[1] : ""
        await recorder.imap(command)

        switch command.split(separator: " ").first.map(String.init) ?? "" {
        case "CAPABILITY":
            respond("* CAPABILITY IMAP4rev1 AUTH=PLAIN SASL-IR UIDPLUS", "\(tag) OK done")
        case "AUTHENTICATE":
            respond("\(tag) OK authenticated")
        case "LIST":
            respond(
                "* LIST (\\HasChildren) \"/\" \"INBOX\"",
                "* LIST (\\HasNoChildren) \"/\" \"INBOX/Klanten\"",
                "* LIST (\\HasNoChildren \\Drafts) \"/\" \"Concepten\"",
                "* LIST (\\HasNoChildren \\Sent) \"/\" \"Verzonden\"",
                "* LIST (\\Noselect \\HasChildren) \"/\" \"Archief\"",
                "\(tag) OK done"
            )
        case "STATUS":
            respond("* STATUS \"INBOX\" (MESSAGES 12 UNSEEN 2 RECENT 0 UIDNEXT 45 UIDVALIDITY 7)", "\(tag) OK done")
        case "EXAMINE":
            respond("* 12 EXISTS", "* OK [UIDVALIDITY 7] ok", "\(tag) OK [READ-ONLY] done")
        case "UID":
            if command.hasPrefix("UID SEARCH") {
                respond("* SEARCH 40 42", "\(tag) OK done")
            } else if command.contains("BODY.PEEK[]") {
                let body = Data(MailFixture.original.utf8)
                output.append(Data("* 2 FETCH (UID 42 BODY[] {\(body.count)}\r\n".utf8))
                output.append(body)
                respond(")", "\(tag) OK done")
            } else {
                respond(
                    "* 1 FETCH (UID 40 FLAGS (\\Seen) INTERNALDATE \"16-Nov-2026 08:00:00 +0100\" RFC822.SIZE 900 ENVELOPE (\"Mon, 16 Nov 2026 08:00:00 +0100\" \"Eerder\" ((\"Sender\" NIL \"sender\" \"example.org\")) NIL NIL NIL NIL NIL NIL NIL))",
                    "* 2 FETCH (UID 42 FLAGS () INTERNALDATE \"17-Nov-2026 09:30:00 +0100\" RFC822.SIZE 1234 ENVELOPE (\"Tue, 17 Nov 2026 09:30:00 +0100\" \"Afspraak volgende week\" ((\"Jan de Vries\" NIL \"jan\" \"example.org\")) NIL NIL ((NIL NIL \"alex\" \"practice.example\")) NIL NIL NIL \"<orig-1@example.org>\"))",
                    "\(tag) OK done"
                )
            }
        case "APPEND":
            // APPEND "box" (flags) {n}
            let quoted = command.split(separator: "\"")
            let flags = command.firstIndex(of: "(").map { String(command[$0...].prefix { $0 != ")" }) + ")" } ?? "()"
            let count = Int(command.split(separator: "{").last?.dropLast() ?? "0") ?? 0
            pendingAppend = (tag, quoted.count > 1 ? String(quoted[1]) : "", flags, count)
            respond("+ go ahead")
        case "LOGOUT":
            respond("* BYE bye", "\(tag) OK done")
        default:
            respond("\(tag) BAD unknown")
        }
    }

    func readLine() async throws -> String {
        guard let range = output.range(of: Data("\r\n".utf8)) else {
            throw MailConnectionError.connectionClosed
        }
        let line = output[output.startIndex..<range.lowerBound]
        output.removeSubrange(output.startIndex..<range.upperBound)
        return String(decoding: line, as: UTF8.self)
    }

    func read(count: Int) async throws -> Data {
        guard output.count >= count else {
            throw MailConnectionError.connectionClosed
        }
        let bytes = Data(output.prefix(count))
        output.removeFirst(count)
        return bytes
    }

    func startTLS() async throws {}
    func close() async {}

    private func respond(_ lines: String...) {
        output.append(Data(lines.map { $0 + "\r\n" }.joined().utf8))
    }
}

/// Accepts a submission and records the commands and message.
actor FakeSMTPServer: MailTransport {
    private let recorder: MailRecorder
    private var output = Data("220 fake ESMTP\r\n".utf8)
    private var inData = false

    init(recorder: MailRecorder) {
        self.recorder = recorder
    }

    func write(_ data: Data) async throws {
        let text = String(decoding: data, as: UTF8.self)
        if inData {
            await recorder.deliver(text)
            if text.hasSuffix("\r\n.\r\n") {
                inData = false
                respond("250 2.0.0 queued as F1")
            }
            return
        }
        let command = text.trimmingCharacters(in: .newlines)
        await recorder.smtp(command)
        let verb = command.split(separator: " ").first.map { $0.uppercased() } ?? ""
        switch verb {
        case "EHLO":
            respond("250-fake", "250 AUTH PLAIN")
        case "AUTH":
            respond("235 ok")
        case "MAIL":
            respond("250 ok")
        case "RCPT":
            respond(command.contains("nobody@") ? "550 no such user" : "250 ok")
        case "DATA":
            inData = true
            respond("354 go")
        case "QUIT":
            respond("221 bye")
        default:
            respond("500 unknown")
        }
    }

    func readLine() async throws -> String {
        guard let range = output.range(of: Data("\r\n".utf8)) else {
            throw MailConnectionError.connectionClosed
        }
        let line = output[output.startIndex..<range.lowerBound]
        output.removeSubrange(output.startIndex..<range.upperBound)
        return String(decoding: line, as: UTF8.self)
    }

    func read(count: Int) async throws -> Data {
        throw MailConnectionError.connectionClosed
    }

    func startTLS() async throws {}
    func close() async {}

    private func respond(_ lines: String...) {
        output.append(Data(lines.map { $0 + "\r\n" }.joined().utf8))
    }
}
