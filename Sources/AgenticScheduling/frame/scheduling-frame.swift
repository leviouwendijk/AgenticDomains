import Foundation
import Frame

/// The `Scheduling` Frame module: what `import Scheduling;` makes nameable
/// in `domains/scheduling.frame`.
///
/// Every `let name: Participant` is a participant identified by its binding
/// name, in declaration order; the first is the default for requests naming
/// nobody. Calendars are bound once and referenced by participants, so a
/// misspelt calendar fails when the file is read. Every `let name: Place` is
/// a known place. The optional `let scheduling: SchedulingSettings` holds
/// defaults.
public enum SchedulingFrame {
    public static let module = Frame.Module("Scheduling", types: [
        .decodable(Calendar.self, named: "Calendar"),
        .decodable(WorkingWeek.self, named: "WorkingWeek"),
        .decodable(Participant.self, named: "Participant"),
        .decodable(Place.self, named: "Place"),
        .decodable(Settings.self, named: "SchedulingSettings"),
    ])

    public static let environment = Frame.Environment([module])

    /// The binding Agentic reads defaults from.
    public static let settingsBinding = "scheduling"

    /// The file's name inside a home's `domains` directory.
    public static let fileName = "scheduling.frame"

    public struct Calendar: Sendable, Hashable, Decodable {
        public let title: String
        public let identifier: String?
        public let role: CalendarRole?
        public let allDayRole: CalendarRole?
        public let overrunMinutes: Int?
        public let offerTitles: [String]?
        public let sharedTravel: Bool?
    }

    /// Working time per weekday as `HH:mm-HH:mm` ranges. A day left out is
    /// not worked.
    public struct WorkingWeek: Sendable, Hashable, Decodable {
        public let monday: [String]?
        public let tuesday: [String]?
        public let wednesday: [String]?
        public let thursday: [String]?
        public let friday: [String]?
        public let saturday: [String]?
        public let sunday: [String]?

        func ranges(on day: ScheduleWeekday) -> [String] {
            switch day {
            case .monday: return monday ?? []
            case .tuesday: return tuesday ?? []
            case .wednesday: return wednesday ?? []
            case .thursday: return thursday ?? []
            case .friday: return friday ?? []
            case .saturday: return saturday ?? []
            case .sunday: return sunday ?? []
            }
        }
    }

    public struct Participant: Sendable, Hashable, Decodable {
        public let name: String?
        public let timeZone: String?
        public let workingHours: WorkingWeek?
        public let calendars: [Calendar]?
        public let home: String?
        public let reservedHours: WorkingWeek?
    }

    public struct Place: Sendable, Hashable, Decodable {
        public let label: String?
        public let latitude: Double
        public let longitude: Double
        public let aliases: [String]?
    }

    public struct Settings: Sendable, Hashable, Decodable {
        public let timeZone: String?
        public let bufferMinutes: Int?
        public let stepMinutes: Int?
        public let travelMode: TravelMode?
        public let placement: SlotPlacement?
        public let defaultDurationMinutes: Int?
        public let defaultOverrunMinutes: Int?
        public let preferredHours: String?
        public let splitTravel: SplitTravelPolicy?
        /// Calendars configured without belonging to a participant.
        public let calendars: [Calendar]?
    }
}

extension SchedulingFrame.Calendar: FrameDescribable {
    public static var frameSchema: Frame.Schema {
        .object([
            .init("title", .string, required: true, summary: "The calendar's title as Apple Calendar (or another source) shows it."),
            .init("identifier", .string, summary: "The source's calendar identifier. When set, it alone decides the match, so a rename does not break it; \(Scheduling.Tools.ListCalendars.identifier.rawValue) lists identifiers."),
            .init("role", .members(of: CalendarRole.self, summaries: [
                .commitments: "Appointments that occupy time, unless an event is marked free. The default.",
                .offers: "Open slots offered for booking. Never block; placement inside one is preferred or required.",
                .reserved: "Held-back time such as internal days. Blocks, whatever an event's availability, unless a request escalates.",
                .records: "History or notes such as cancellations. Ignored.",
            ]), summary: "How the calendar's events are read."),
            .init("allDayRole", .members(of: CalendarRole.self), summary: "How its all-day events are read, when that differs from role: for example timed meetings as commitments and all-day office days as reserved."),
            .init("overrunMinutes", .integer, summary: "How far its appointments usually run past their end. A soft margin, never an exclusion."),
            .init("offerTitles", .array(.string), summary: "For an offers calendar: title fragments that mark a slot as still open, such as \"Slot\". An event titled otherwise is a provisional booking and blocks. Absent means every event is open."),
            .init("sharedTravel", .boolean, summary: "Its participants travel together in one vehicle, so they must arrive from and leave for the same place."),
        ], summary: "A calendar and how scheduling reads it.")
    }
}

extension SchedulingFrame.WorkingWeek: FrameDescribable {
    public static var frameSchema: Frame.Schema {
        let day = Frame.Schema.array(.string, summary: "Ranges such as \"09:00-17:00\"; 24:00 ends the day.")
        return .object(
            ScheduleWeekday.allCases.map { .init($0.rawValue, day) },
            summary: "Working time per weekday in the participant's zone. A day left out is not worked."
        )
    }
}

extension SchedulingFrame.Participant: FrameDescribable {
    public static var frameSchema: Frame.Schema {
        .object([
            .init("name", .string, summary: "Display name; the binding name when absent. Requests may use either."),
            .init("timeZone", .string, summary: "IANA zone; the settings' zone when absent."),
            .init("workingHours", .of(SchedulingFrame.WorkingWeek.self), summary: "Monday to Friday 09:00-17:00 when absent."),
            .init("calendars", .array(.of(SchedulingFrame.Calendar.self)), summary: "Calendars that represent this person's time, shared ones included. Empty or absent means every calendar."),
            .init("home", .string, summary: "Where the day usually starts and ends: an address, or a Place's name or alias. Travel from and to it counts towards added travel, never as a hard limit."),
            .init("reservedHours", .of(SchedulingFrame.WorkingWeek.self), summary: "Time held back by default each week, such as an office day or development days. Opened by escalation, or by an offered slot placed inside it."),
        ], summary: "Someone whose time scheduling reasons about, identified by the binding name. The first declared is the default.")
    }
}

extension SchedulingFrame.Place: FrameDescribable {
    public static var frameSchema: Frame.Schema {
        .object([
            .init("label", .string, summary: "Name used in results; the binding name when absent."),
            .init("latitude", .decimal, required: true),
            .init("longitude", .decimal, required: true),
            .init("aliases", .array(.string), summary: "Other location texts, as written in events, that mean this place. Matching ignores case and spacing."),
        ], summary: "A known place for travel estimates.")
    }
}

extension SchedulingFrame.Settings: FrameDescribable {
    public static var frameSchema: Frame.Schema {
        .object([
            .init("timeZone", .string, summary: "Default IANA zone; the system's when absent."),
            .init("bufferMinutes", .integer, summary: "Free minutes kept around new appointments and expected between existing ones. Default 0."),
            .init("stepMinutes", .integer, summary: "Granularity of candidate start times. Default 15."),
            .init("travelMode", .members(of: TravelMode.self), summary: "Default travel mode. Default driving."),
            .init("placement", .members(of: SlotPlacement.self, summaries: [
                .offered_only: "Each required participant who offers slots must have one covering the appointment.",
                .prefer_offered: "Offered slots score higher; open time is still feasible. The default.",
                .any: "Offered slots play no part.",
            ]), summary: "How offered slots constrain placement."),
            .init("defaultDurationMinutes", .integer, summary: "Appointment length when a request does not say. Default 60."),
            .init("defaultOverrunMinutes", .integer, summary: "How far a new appointment may run over when a request does not say; kept free as a soft margin. Default 0."),
            .init("splitTravel", .members(of: SplitTravelPolicy.self, summaries: [
                .avoid: "A placement that splits a shared trip is excluded unless the request allows it. The default.",
                .warn: "Splitting only lowers the score.",
            ]), summary: "What splitting a shared trip means: it needs a second vehicle."),
            .init("preferredHours", .string, summary: "Hours appointments preferably fall in, such as \"10:00-17:00\"; scored, never enforced, unless a request sets its own time of day."),
            .init("calendars", .array(.of(SchedulingFrame.Calendar.self)), summary: "Calendars configured without belonging to a participant."),
        ], summary: "Scheduling defaults. Every field is optional.")
    }
}
