import Agentic
import AgenticAppleServices
import AgenticExecution
import AgenticPrograms
import AgenticRuntime
import TestFlows

private actor CreateReminderProviderFixture:
    AppleRemindersProvider
{
    private var authorization: RemindersAuthorizationStatus
    private let requestedAuthorization:
        RemindersAuthorizationStatus
    private var accessRequests = 0
    private var created: [ReminderCreation] = []

    init(
        authorization: RemindersAuthorizationStatus,
        requestedAuthorization: RemindersAuthorizationStatus
    ) {
        self.authorization = authorization
        self.requestedAuthorization = requestedAuthorization
    }

    func authorizationStatus() async
        -> RemindersAuthorizationStatus
    {
        authorization
    }

    func requestFullAccess() async throws
        -> RemindersAuthorizationRequestResult
    {
        accessRequests += 1
        authorization = requestedAuthorization

        return .init(
            granted: requestedAuthorization == .full_access,
            status: requestedAuthorization
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

    func accessRequestCount() -> Int {
        accessRequests
    }

    func creations() -> [ReminderCreation] {
        created
    }
}

private struct CreateReminderScenario {
    let provider: CreateReminderProviderFixture
    let runner: AgentProgramRunner

    init(
        authorization: RemindersAuthorizationStatus = .full_access,
        requestedAuthorization: RemindersAuthorizationStatus =
            .full_access
    ) throws {
        let provider = CreateReminderProviderFixture(
            authorization: authorization,
            requestedAuthorization: requestedAuthorization
        )
        let registry = try ToolRegistry {
            RemindersAuthorizationStatusTool(
                provider: provider
            )
            RemindersRequestFullAccessTool(
                provider: provider
            )
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

        let authorizationScenario = try CreateReminderScenario(
            authorization: .not_determined
        )
        let authorizationInitial = try await authorizationScenario.runner.execute(
            program,
            input: input,
            sessionID: "domain-create-reminder-authorization"
        )

        guard let authorizationCheckpoint =
            authorizationInitial.record.checkpoint
        else {
            throw CreateReminderProgramFixtureError
                .missing_checkpoint
        }
        guard let authorizationRequest =
            authorizationInitial.record.interactionRequest
        else {
            throw CreateReminderProgramFixtureError
                .missing_interaction_request
        }
        guard let authorizationPending =
            authorizationRequest.requirement.pendingApproval
        else {
            throw CreateReminderProgramFixtureError
                .missing_pending_approval
        }

        try Expect.equal(
            authorizationInitial.record.outcome,
            .suspended,
            "not-determined Reminders access suspends at the governed permission request"
        )
        try Expect.equal(
            authorizationPending.toolCall.name,
            RemindersRequestFullAccessTool.toolIdentifier.rawValue,
            "authorization prerequisite suspends on the explicit Reminders access request tool"
        )
        try Expect.equal(
            await authorizationScenario.provider.accessRequestCount(),
            0,
            "macOS access request is not issued before Agentic approval"
        )
        try Expect.equal(
            await authorizationScenario.provider.creations().count,
            0,
            "reminder creation cannot occur before authorization"
        )

        let authorizationApproved = try await authorizationScenario.runner.resume(
            program,
            from: authorizationCheckpoint,
            interaction: .init(
                request: authorizationRequest,
                resolution: .approval(.approved)
            )
        )

        guard let creationCheckpoint =
            authorizationApproved.record.checkpoint
        else {
            throw CreateReminderProgramFixtureError
                .missing_checkpoint
        }
        guard let creationRequest =
            authorizationApproved.record.interactionRequest
        else {
            throw CreateReminderProgramFixtureError
                .missing_interaction_request
        }
        guard let creationPending =
            creationRequest.requirement.pendingApproval
        else {
            throw CreateReminderProgramFixtureError
                .missing_pending_approval
        }

        try Expect.equal(
            authorizationApproved.record.outcome,
            .suspended,
            "approved permission request continues to the separate reminder mutation approval"
        )
        try Expect.equal(
            await authorizationScenario.provider.accessRequestCount(),
            1,
            "approved authorization prerequisite requests access exactly once"
        )
        try Expect.equal(
            await authorizationScenario.provider.creations().count,
            0,
            "granting access does not itself create the reminder"
        )
        try Expect.equal(
            creationPending.toolCall.name,
            RemindersCreateTool.toolIdentifier.rawValue,
            "second suspension is the actual reminder creation mutation"
        )

        let authorizationCreated = try await authorizationScenario.runner.resume(
            program,
            from: creationCheckpoint,
            interaction: .init(
                request: creationRequest,
                resolution: .approval(.approved)
            )
        )

        try Expect.equal(
            authorizationCreated.record.outcome,
            .succeeded,
            "authorization followed by creation approval completes the Program"
        )
        try Expect.equal(
            await authorizationScenario.provider.accessRequestCount(),
            1,
            "deterministic replay does not repeat the completed access request"
        )
        try Expect.equal(
            await authorizationScenario.provider.creations(),
            [input],
            "two-stage authorization and mutation flow creates exactly one reminder"
        )

        let accessDeniedScenario = try CreateReminderScenario(
            authorization: .not_determined
        )
        let accessDeniedInitial = try await accessDeniedScenario.runner.execute(
            program,
            input: input,
            sessionID: "domain-create-reminder-access-denied"
        )

        guard let accessDeniedCheckpoint =
            accessDeniedInitial.record.checkpoint
        else {
            throw CreateReminderProgramFixtureError
                .missing_checkpoint
        }
        guard let accessDeniedRequest =
            accessDeniedInitial.record.interactionRequest
        else {
            throw CreateReminderProgramFixtureError
                .missing_interaction_request
        }

        let accessDenied = try await accessDeniedScenario.runner.resume(
            program,
            from: accessDeniedCheckpoint,
            interaction: .init(
                request: accessDeniedRequest,
                resolution: .approval(.denied)
            )
        )

        try Expect.equal(
            accessDenied.record.outcome,
            .failed,
            "denying the governed access request fails closed"
        )
        try Expect.equal(
            await accessDeniedScenario.provider.accessRequestCount(),
            0,
            "denying Agentic authorization review never invokes the macOS permission request"
        )
        try Expect.equal(
            await accessDeniedScenario.provider.creations().count,
            0,
            "denied access request cannot create a reminder"
        )

        let osDeniedScenario = try CreateReminderScenario(
            authorization: .not_determined,
            requestedAuthorization: .denied
        )
        let osDeniedInitial = try await osDeniedScenario.runner.execute(
            program,
            input: input,
            sessionID: "domain-create-reminder-os-denied"
        )

        guard let osDeniedCheckpoint =
            osDeniedInitial.record.checkpoint
        else {
            throw CreateReminderProgramFixtureError
                .missing_checkpoint
        }
        guard let osDeniedRequest =
            osDeniedInitial.record.interactionRequest
        else {
            throw CreateReminderProgramFixtureError
                .missing_interaction_request
        }

        let osDenied = try await osDeniedScenario.runner.resume(
            program,
            from: osDeniedCheckpoint,
            interaction: .init(
                request: osDeniedRequest,
                resolution: .approval(.approved)
            )
        )

        try Expect.equal(
            osDenied.record.outcome,
            .failed,
            "Program fails cleanly when the OS permission request returns denied"
        )
        try Expect.equal(
            await osDeniedScenario.provider.accessRequestCount(),
            1,
            "approved Agentic request reaches the OS authorization provider exactly once"
        )
        try Expect.equal(
            await osDeniedScenario.provider.creations().count,
            0,
            "OS-denied authorization never reaches reminder creation"
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
