import Agentic
import AgenticContext
import AgenticStandard
import Macros
import Schema

/// Three mailbox agents with one loop (index → plan → approval → apply) and
/// three purposes: structure, reduction and malice.
public extension Email.Agents {
    @Agent
    enum Organizer {
        public typealias Input = String
        public typealias Output = String

        public static let purpose = """
        Mailbox organizer: restructures an account by what mail is (records, \
        correspondence, notifications, newsletters) into mailboxes, through \
        plans the owner approves.
        """

        public static let instructions: AgentInstructions = [
            .instruction(Email.Instructions.Handling.definition),
            .instruction(Email.Instructions.Planning.definition),
            .instruction(Email.Instructions.Organizing.definition),
            .instruction(Context.Instructions.Gathering.definition),
        ]

        public static let capabilities = Email.mailboxCapabilities(extra: [
            Email.Tools.Suspicious.identifier,
        ])
    }

    @Agent
    enum Cleaner {
        public typealias Input = String
        public typealias Output = String

        public static let purpose = """
        Mailbox cleaner: finds what is no longer needed (old newsletters and \
        notifications, unread bulk senders) and moves it to Pruned through \
        plans the owner approves; never deletes.
        """

        public static let instructions: AgentInstructions = [
            .instruction(Email.Instructions.Handling.definition),
            .instruction(Email.Instructions.Planning.definition),
            .instruction(Email.Instructions.Cleaning.definition),
            .instruction(Context.Instructions.Gathering.definition),
        ]

        public static let capabilities = Email.mailboxCapabilities(extra: [])
    }

    @Agent
    enum Scanner {
        public typealias Input = String
        public typealias Output = String

        public static let purpose = """
        Mail scanner: finds fraud and phishing (fake invoices, impersonation, \
        lookalike domains), explains each suspect against what the owner \
        actually uses, and proposes review moves and blocks; decisions stay \
        with the owner.
        """

        public static let instructions: AgentInstructions = [
            .instruction(Email.Instructions.Handling.definition),
            .instruction(Email.Instructions.Planning.definition),
            .instruction(Email.Instructions.Scanning.definition),
            .instruction(Context.Instructions.Gathering.definition),
        ]

        public static let capabilities = Email.mailboxCapabilities(extra: [
            Email.Tools.Suspicious.identifier,
            Email.Tools.Decide.identifier,
        ])
    }
}

extension Email {
    /// What every mailbox agent sees: accounts, access, reading, the index and
    /// the plan loop, plus `extra`. No drafting or sending.
    static func mailboxCapabilities(
        extra: [ToolIdentifier]
    ) -> AgentCapabilities {
        AgentCapabilities(
            available: .init(
                domains: [
                    Email.self,
                ],
                tools: .init(
                    members: [
                        Standard.Tools.ClarifyWithUser.identifier,
                        Standard.Tools.CurrentDatetime.identifier,
                        Standard.Tools.CreateReport.identifier,
                    ]
                )
            ),
            visible: .init(
                tools: .init(
                    members: [
                        Email.Tools.ListAccounts.identifier,
                        Email.Tools.RequestAccess.identifier,
                        Email.Tools.ListMailboxes.identifier,
                        Email.Tools.Search.identifier,
                        Email.Tools.Read.identifier,
                        Email.Tools.IndexSync.identifier,
                        Email.Tools.Clutter.identifier,
                        Email.Tools.Plan.identifier,
                        Email.Tools.Plans.identifier,
                        Email.Tools.Apply.identifier,
                        Email.Tools.Undo.identifier,

                        Standard.Tools.CurrentDatetime.identifier,
                        Standard.Tools.CreateReport.identifier,
                        Standard.Tools.ClarifyWithUser.identifier,
                    ] + extra
                )
            )
        )
    }
}
