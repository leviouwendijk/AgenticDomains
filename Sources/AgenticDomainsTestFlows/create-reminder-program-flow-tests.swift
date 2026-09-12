import Agentic
import AgenticAppleServices
import AgenticExecution
import AgenticPrograms
import AgenticRuntime
import TestFlows

private actor CreateReminderProviderFixture:
    AppleRemindersProvider
{
    private var created: [ReminderCreation] = []

    func authorizationStatus() async
        -> RemindersAuthorizationStatus
    {
        .full_access
    }

    func requestFullAccess() async throws
        -> RemindersAuthorizationRequestResult
    {
        .init(
            granted: true,
            status: .full_access
        )
    }

    func reminders(
        limit: Int
    ) async throws -> [ReminderItem] {
        _ = limit
        return []
    }

    func createReminder(
        _ creation: ReminderCreation
    ) async throws -> ReminderItem {
        created.append(creation)

        return ReminderItem(
            identifier: "fixture.created.\(created.count)",
            title: creation.title,
            isCompleted: false,
            dueDate: nil,
            completionDate: nil,
            calendarTitle:
                creation.listTitle ?? "Reminders",
            notes: creation.notes,
            priority: 0
        )
    }

    func creations() -> [ReminderCreation] {
        created
    }
}

private struct CreateReminderScenario {
    let provider: CreateReminderProviderFixture
    let runner: AgentProgramRunner

    init() throws {
        let provider = CreateReminderProviderFixture()
        let registry = try ToolRegistry {
            RemindersCreateTool(
                provider: provider
            )
        }

        self.provider = provider
        self.runner = AgentProgramRunner(
            services: .init(
                program: .init(
                    tools: GovernedAgentProgramToolExecutor(
                        registry: registry,
                        policy: .init(
                            autonomyMode: .auto_observe
                        )
                    )
                )
            )
        )
    }
}

private enum CreateReminderProgramFixtureError:
    Error
{
    case missing_checkpoint
    case missing_interaction_request
    case missing_pending_approval
    case missing_output
}

extension AgenticDomainsFlowTesting {
    static func runCreateReminderProgram()
        async throws
        -> [TestFlowDiagnostic]
    {
        let program = CreateReminderProgram()
        let input = ReminderCreation(
            title: "File expenses",
            notes: "Before Friday",
            listTitle: "Work"
        )

        let approvedScenario = try CreateReminderScenario()
        let approvedInitial = try await approvedScenario.runner.execute(
            program,
            input: input,
            sessionID: "domain-create-reminder-approved"
        )

        guard let approvedCheckpoint =
            approvedInitial.record.checkpoint
        else {
            throw CreateReminderProgramFixtureError
                .missing_checkpoint
        }

        guard let approvedRequest =
            approvedInitial.record.interactionRequest
        else {
            throw CreateReminderProgramFixtureError
                .missing_interaction_request
        }

        guard let approvedPending =
            approvedRequest.requirement.pendingApproval
        else {
            throw CreateReminderProgramFixtureError
                .missing_pending_approval
        }

        try Expect.equal(
            approvedInitial.record.outcome,
            .suspended,
            "real Domain mutation Program suspends before reminder creation"
        )
        try Expect.equal(
            await approvedScenario.provider.creations().count,
            0,
            "reminder provider receives no write before approval"
        )
        try Expect.equal(
            approvedRequest.kind,
            .approval,
            "reminder mutation uses the shared approval interaction"
        )
        try Expect.equal(
            approvedPending.toolCall.name,
            RemindersCreateTool.toolIdentifier.rawValue,
            "Program suspension identifies the governed reminder creation tool"
        )
        try Expect.equal(
            approvedPending.preflight.risk,
            .boundedmutate,
            "reminder creation is preflighted as a bounded mutation"
        )
        try Expect.equal(
            approvedPending.preflight.summary,
            "Create reminder 'File expenses' in Work.",
            "preflight states the exact semantic reminder mutation under review"
        )

        let approved = try await approvedScenario.runner.resume(
            program,
            from: approvedCheckpoint,
            interaction: .init(
                request: approvedRequest,
                resolution: .approval(.approved)
            )
        )
        let approvedCreations =
            await approvedScenario.provider.creations()

        try Expect.equal(
            approved.record.outcome,
            .succeeded,
            "approved reminder creation resumes to completion"
        )
        try Expect.equal(
            approvedCreations,
            [input],
            "approved Program executes the originally reviewed reminder mutation exactly once"
        )

        guard let approvedOutputValue = approved.record.output else {
            throw CreateReminderProgramFixtureError
                .missing_output
        }

        let approvedOutput = try JSONToolBridge.decode(
            ReminderItem.self,
            from: approvedOutputValue
        )

        try Expect.equal(
            approvedOutput.title,
            input.title,
            "Program returns the typed created reminder"
        )
        try Expect.equal(
            approvedOutput.calendarTitle,
            "Work",
            "Program result preserves the selected reminder list"
        )

        let deniedScenario = try CreateReminderScenario()
        let deniedInitial = try await deniedScenario.runner.execute(
            program,
            input: input,
            sessionID: "domain-create-reminder-denied"
        )

        guard let deniedCheckpoint = deniedInitial.record.checkpoint else {
            throw CreateReminderProgramFixtureError
                .missing_checkpoint
        }
        guard let deniedRequest = deniedInitial.record.interactionRequest else {
            throw CreateReminderProgramFixtureError
                .missing_interaction_request
        }

        let denied = try await deniedScenario.runner.resume(
            program,
            from: deniedCheckpoint,
            interaction: .init(
                request: deniedRequest,
                resolution: .approval(.denied)
            )
        )

        try Expect.equal(
            denied.record.outcome,
            .failed,
            "denied reminder creation fails closed"
        )
        try Expect.equal(
            await deniedScenario.provider.creations().count,
            0,
            "denied reminder creation never reaches its provider"
        )

        let skippedScenario = try CreateReminderScenario()
        let skippedInitial = try await skippedScenario.runner.execute(
            program,
            input: input,
            sessionID: "domain-create-reminder-skipped"
        )

        guard let skippedCheckpoint = skippedInitial.record.checkpoint else {
            throw CreateReminderProgramFixtureError
                .missing_checkpoint
        }
        guard let skippedRequest = skippedInitial.record.interactionRequest else {
            throw CreateReminderProgramFixtureError
                .missing_interaction_request
        }

        let skipped = try await skippedScenario.runner.resume(
            program,
            from: skippedCheckpoint,
            interaction: .init(
                request: skippedRequest,
                resolution: .approval(.skipped)
            )
        )

        try Expect.equal(
            skipped.record.outcome,
            .failed,
            "skipped reminder creation fails closed"
        )
        try Expect.equal(
            await skippedScenario.provider.creations().count,
            0,
            "skipped reminder creation never reaches its provider"
        )

        return [
            .field(
                "initial_outcome",
                approvedInitial.record.outcome.rawValue
            ),
            .field(
                "approved_creations",
                String(approvedCreations.count)
            ),
            .field(
                "denied_creations",
                String(
                    await deniedScenario.provider
                        .creations().count
                )
            ),
            .field(
                "skipped_creations",
                String(
                    await skippedScenario.provider
                        .creations().count
                )
            ),
            .field(
                "approved_output",
                approvedOutput.title
            ),
        ]
    }
}
