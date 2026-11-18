import Agentic
import AgenticFrame
import AgenticContext
import AgenticStandard
import Macros
import Schema

public extension Scheduling.Agents {
    /// Writes and refines the team's `scheduling.frame` with the user:
    /// reads the real calendars, asks what they cannot tell, and saves only
    /// a file that checks out.
    @Agent
    enum Configurator {
        public typealias Input = String
        public typealias Output = String

        public static let purpose = """
        Scheduling setup: writes or refines the team's \(SchedulingFrame.fileName) \
        (participants, calendars and their roles, working hours, places, \
        defaults) from the real calendars and the user's answers, and saves \
        it once it checks out.
        """

        public static let instructions: AgentInstructions = [
            .instruction(Context.Instructions.Gathering.definition),
            .text(
                """
                You set up scheduling for the user's team by writing its \
                configuration file, \(SchedulingFrame.fileName), in the Frame \
                language. You either write a first file or refine the current \
                one; \(Scheduling.Tools.ReadConfiguration.identifier.rawValue) \
                tells you which, and gives a complete example to follow.

                START FROM WHAT IS THERE

                Read the current file with \
                \(Scheduling.Tools.ReadConfiguration.identifier.rawValue) and the \
                real calendars with \(Scheduling.Tools.ListCalendars.identifier.rawValue). \
                Use calendar titles exactly as listed, and set each calendar's \
                `.identifier` from that list so a later rename does not break it. \
                Read \(FrameLang.Tools.ModuleSchema.identifier.rawValue) for the \
                `Scheduling` module when you need a field's meaning or allowed \
                values. When refining, change only what the user asks for and \
                keep everything else, comments included.

                ASK ONLY WHAT THE CALENDARS CANNOT TELL

                Calendars show names, not meaning. Ask the user, with \
                \(Standard.Tools.ClarifyWithUser.identifier.rawValue), who the \
                participants are and which calendars represent whose time; how \
                each calendar is read, when a title does not make it obvious:
                \(SchemaInstructionText.values(of: CalendarRole.self))
                and working hours, homes, places and defaults only as far as \
                the user cares. Group questions; do not ask one field at a \
                time. Never invent people, addresses or coordinates: leave a \
                field out, or write it commented out, rather than guess.

                CHECK, SHOW, SAVE

                Run \(Scheduling.Tools.CheckConfiguration.identifier.rawValue) \
                on the whole file and fix what it reports until it is valid. \
                An unknown calendar is usually a misspelt title; save one \
                anyway only when the user confirms it exists elsewhere. Show \
                the user the file, or for a refinement what changes, and save \
                with \(Scheduling.Tools.SaveConfiguration.identifier.rawValue) \
                once they agree. The previous file is archived. Scheduling \
                uses the saved file at once.

                Report briefly what the file now says and anything left open.
                """
            ),
        ]

        public static let capabilities = AgentCapabilities(
            available: .init(
                domains: [
                    Scheduling.self,
                    FrameLang.self,
                ],
                tools: .init(
                    members: [
                        Standard.Tools.ClarifyWithUser.identifier,
                        Standard.Tools.InspectCapability.identifier,
                    ]
                )
            ),
            visible: .init(
                tools: .init(
                    members: [
                        Scheduling.Tools.ReadConfiguration.identifier,
                        Scheduling.Tools.ListCalendars.identifier,
                        Scheduling.Tools.CheckConfiguration.identifier,
                        Scheduling.Tools.SaveConfiguration.identifier,

                        FrameLang.Tools.ModuleSchema.identifier,
                        FrameLang.Tools.Check.identifier,

                        Standard.Tools.ClarifyWithUser.identifier,
                        Standard.Tools.InspectCapability.identifier,
                    ]
                )
            )
        )

        // The model serving `.planner` is bound by the application.
        public static let modelSelection = AgentModelSelection(
            purpose: .planner
        )
    }
}
