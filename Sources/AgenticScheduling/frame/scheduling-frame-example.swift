import Foundation

public extension SchedulingFrame {
    /// A complete `domains/scheduling.frame` for a small team, with made-up
    /// people, calendars and places: `agentic example scheduling` prints it.
    /// The tests read it as a configuration, so it stays valid.
    static let example = #"""
        import Scheduling;

        // Calendars, by their titles in Apple Calendar. Bind each once and
        // reference it from participants, so a misspelt calendar fails when
        // the file is read. `agentic` lists identifiers through the
        // scheduling tools; set `.identifier` to survive a rename.
        let appointments_a: Calendar = .{
            .title = "Appointments Alex",
            // How far appointments usually run past their end; a soft margin.
            .overrunMinutes = 15,
        };
        let appointments_b: Calendar = .{ .title = "Appointments Sam", .overrunMinutes = 15 };

        // A calendar both people share; they travel together for its events.
        let joint: Calendar = .{ .title = "Joint", .sharedTravel = true };

        // Open slots offered for booking: placing inside one is preferred.
        // An event titled otherwise ("Booked: ...") is a provisional booking.
        let offers_a: Calendar = .{
            .title = "Open slots Alex",
            .role = .offers,
            .offerTitles = ["Slot"],
        };

        // Held-back time: blocks unless a request escalates.
        // Timed events are commitments; all-day ones mark office days.
        let internal: Calendar = .{
            .title = "Internal",
            .role = .commitments,
            .allDayRole = .reserved,
        };

        // History only (cancellations): ignored.
        let cancelled: Calendar = .{ .title = "Cancelled", .role = .records };

        // Participants, by binding name; the first is the default when a
        // request names nobody.
        let alex: Participant = .{
            .name = "Alex",
            .about = "Runs home visits and most first appointments.",
            .home = "office",
            .workingHours = .{
                .monday = ["09:00-17:00"],
                .tuesday = ["09:00-17:00"],
                .wednesday = ["09:00-12:30"],
                .thursday = ["09:00-17:00"],
                .friday = ["09:00-15:00"],
            },
            .reservedHours = .{ .friday = ["13:00-15:00"] },
            .calendars = [appointments_a, joint, offers_a, internal, cancelled],
        };

        let sam: Participant = .{
            .name = "Sam",
            .about = "Joins group sessions and follow-ups.",
            .timeZone = "Europe/Amsterdam",
            .workingHours = .{
                .tuesday = ["10:00-18:00"],
                .thursday = ["10:00-18:00"],
            },
            .calendars = [appointments_b, joint, internal, cancelled],
        };

        // Known places for travel estimates; aliases match event locations.
        let office: Place = .{
            .label = "Office",
            .latitude = 52.0907,
            .longitude = 5.1214,
            .aliases = ["kantoor", "HQ"],
        };

        // Defaults; every field is optional.
        let scheduling: SchedulingSettings = .{
            .timeZone = "Europe/Amsterdam",
            .bufferMinutes = 15,
            .stepMinutes = 15,
            .travelMode = .driving,
            // .offered_only, .prefer_offered, .any
            .placement = .prefer_offered,
            .defaultDurationMinutes = 60,
            .preferredHours = "10:00-16:00",
            // .avoid, .warn
            .splitTravel = .avoid,
            .context = """
                We are a two-person team doing appointments at clients' homes.
                Appointment titles start with the client's name. "Intake" means a
                first appointment of 90 minutes with Alex.
                """,
        };
        """#
}
