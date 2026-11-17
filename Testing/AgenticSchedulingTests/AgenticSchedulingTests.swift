import Agentic
import AgenticScheduling
import Foundation
import Testing

private enum AgenticSchedulingTestingFailure: Error {
    case failed
}

@main
struct AgenticSchedulingTestingMain {
    static func main() async throws {
        let reporter = PlainTextTestReporter(
            output: ClosureTestTextOutput { text in
                FileHandle.standardOutput.write(Data(text.utf8))
            }
        )
        let result = await TestRunner.run(
            AgenticSchedulingTestSuite.suite,
            sink: reporter
        )
        if result.isFailure {
            throw AgenticSchedulingTestingFailure.failed
        }
    }
}

enum AgenticSchedulingTestSuite {
    static let suite = TestSuite(
        "agentic-scheduling",
        title: "AgenticScheduling"
    ) {
        Test("invariants-reject-invalid-values") {
            try SchedulingInvariantTests.run()
        }
        Test("busy-time-merges-and-clips") {
            try await SchedulingBusyTests.run()
        }
        Test("find-slots-respects-busy-time-and-working-hours") {
            try await SchedulingSlotTests.basic()
        }
        Test("find-slots-applies-buffers") {
            try await SchedulingSlotTests.buffers()
        }
        Test("find-slots-ranks-by-preferences") {
            try await SchedulingSlotTests.preferences()
        }
        Test("find-slots-reports-optional-attendance") {
            try await SchedulingSlotTests.optionalAttendance()
        }
        Test("find-slots-reports-rejections-when-nothing-fits") {
            try await SchedulingSlotTests.nothingFits()
        }
        Test("evaluate-checks-travel-to-adjacent-located-events") {
            try await SchedulingTravelTests.evaluate()
        }
        Test("travel-estimate-resolves-or-reports") {
            try await SchedulingTravelTests.estimate()
        }
        Test("conflicts-find-overlap-and-impossible-travel") {
            try await SchedulingConflictTests.run()
        }
        Test("calendars-report-invisible-configured-calendars") {
            try await SchedulingCalendarTests.run()
        }
        Test("unknown-participant-is-an-error") {
            try await SchedulingSlotTests.unknownParticipant()
        }
        Test("team-offered-slots-preferred-records-ignored") {
            try await SchedulingTeamWorkflowTests.offeredSlotsPreferred()
        }
        Test("team-offered-only-for-duo") {
            try await SchedulingTeamWorkflowTests.offeredOnlyForDuo()
        }
        Test("team-reserved-time-is-an-escalation") {
            try await SchedulingTeamWorkflowTests.reservedTimeIsAnEscalation()
        }
        Test("team-overrun-is-a-soft-margin") {
            try await SchedulingTeamWorkflowTests.overrunIsASoftMargin()
        }
        Test("team-conflicts-overrun-and-reserved") {
            try await SchedulingTeamWorkflowTests.conflicts()
        }
        Test("team-busy-shows-reserved-and-open-offers") {
            try await SchedulingTeamWorkflowTests.busyShowsReservedAndOpenOffers()
        }
        Test("team-calendars-show-roles") {
            try await SchedulingTeamWorkflowTests.calendarsShowRoles()
        }
        Test("frame-configuration-reads-team") {
            try await SchedulingFrameTests.readsTeam()
        }
        Test("frame-configuration-rejects-invalid-files") {
            try SchedulingFrameTests.rejectsInvalid()
        }
        Test("tools-report-configuration-state") {
            try await SchedulingFrameTests.reportsConfigurationState()
        }
        Test("all-day-role-reads-office-days-apart-from-meetings") {
            try await SchedulingAllDayRoleTests.run()
        }
        Test("added-travel-prefers-nearby-placements") {
            try await SchedulingTravelPreferenceTests.run()
        }
        Test("reserved-hours-open-by-slot-or-escalation") {
            try await SchedulingReservedHoursTests.run()
        }
        Test("agenda-lists-events-as-read") {
            try await SchedulingAgendaTests.run()
        }
        Test("now-gives-anchored-windows") {
            try SchedulingNowTests.run()
        }
        Test("propose-reevaluates-every-option") {
            try await SchedulingPresentationTests.reevaluates()
        }
        Test("propose-presents-timeline-and-options") {
            try await SchedulingPresentationTests.presentsProposal()
        }
        Test("scheduler-presents-proposals-and-reports") {
            try SchedulingPresentationTests.schedulerPresents()
        }
        Test("intermediate-results-are-inspector-only") {
            try await SchedulingPresentationTests.intermediateResultsAreInspectorOnly()
        }
    }
}
