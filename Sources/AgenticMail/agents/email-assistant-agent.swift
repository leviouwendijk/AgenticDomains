import Agentic
import AgenticContext
import AgenticStandard
import Macros
import Schema

public extension Email.Agents {
    @Agent
    enum Assistant {
        public typealias Input = String
        public typealias Output = String

        public static let purpose = """
        Mail assistant: finds and summarizes messages across the configured \
        accounts and folders, and drafts replies; sends only on request and \
        within each account's sending policy.
        """

        public static let instructions: AgentInstructions = [
            .instruction(Email.Instructions.Handling.definition),
            .instruction(Context.Instructions.Gathering.definition),
            .text(
                """
                Resolve relative dates ("this week", "since Monday") from \
                \(Standard.Tools.CurrentDatetime.identifier.rawValue) into \
                yyyy-MM-dd for mail_search. When several accounts could hold \
                what the user means and the request does not say, search the \
                default account first and say which you searched.
                """
            ),
        ]

        public static let capabilities = AgentCapabilities(
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
                        Email.Tools.SaveAttachment.identifier,
                        Email.Tools.SaveDraft.identifier,
                        Email.Tools.Send.identifier,

                        Standard.Tools.CurrentDatetime.identifier,
                        Standard.Tools.CreateReport.identifier,
                        Standard.Tools.ClarifyWithUser.identifier,
                    ]
                )
            )
        )
    }
}
