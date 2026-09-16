import Agentic
import AgenticAppleServices
import AgenticExecution
import AgenticPrograms
import AgenticRecovery
import AgenticRuntime
import TestFlows

private enum ReminderSemanticRecoveryMode: Sendable {
    case authorizationRace
    case unrelatedFailure
}

private enum ReminderSemanticRecoveryFixtureError:
    Error,
    Sendable
{
    case unrelatedFailure
}

private struct ReminderSemanticRecoveryCounts:
    Sendable
{
    let accessRequests: Int
    let createCalls: Int
    let creations: Int
}

private actor ReminderSemanticRecoveryProvider:
    AppleRemindersProvider
{
    private let mode: ReminderSemanticRecoveryMode
    private var authorization: RemindersAuthorizationStatus =
        .full_access
    private var accessRequests = 0
    private var createCalls = 0
    private var created: [ReminderCreation] = []

    init(
        mode: ReminderSemanticRecoveryMode
    ) {
        self.mode = mode
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
        authorization = .full_access

        return .init(
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
        createCalls += 1

        switch mode {
        case .authorizationRace where createCalls == 1:
            authorization = .not_determined
            throw RemindersAuthorizationRequiredError(
                status: .not_determined
            )

        case .unrelatedFailure:
            throw ReminderSemanticRecoveryFixtureError
                .unrelatedFailure

        case .authorizationRace:
            created.append(creation)

            return ReminderItem(
                identifier: "fixture.semantic-recovery.\(created.count)",
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
    }

    func counts() -> ReminderSemanticRecoveryCounts {
        .init(
            accessRequests: accessRequests,
            createCalls: createCalls,
            creations: created.count
        )
    }
}

private struct ReminderSemanticRecoveryApprovalHandler:
    ToolApprovalHandler
{
    func decide(
        on _: ToolPreflight,
        requirement _: ApprovalRequirement
    ) async throws -> ApprovalDecision {
        .approved
    }
}

private struct ReminderSemanticRecoveryScenario {
    let provider: ReminderSemanticRecoveryProvider
    let runner: AgentProgramRunner

    init(
        mode: ReminderSemanticRecoveryMode
    ) throws {
        let provider = ReminderSemanticRecoveryProvider(
            mode: mode
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
                        ),
                        approvalHandler:
                            ReminderSemanticRecoveryApprovalHandler()
                    )
                )
            )
        )
    }
}

extension AgenticDomainsFlowTesting {
    static func runCreateReminderSemanticRecovery()
        async throws
        -> [TestFlowDiagnostic]
    {
        let input = ReminderCreation(
            title: "Semantic recovery fixture",
            notes: "Created after an authorization race",
            listTitle: nil
        )
        let recoveredScenario = try ReminderSemanticRecoveryScenario(
            mode: .authorizationRace
        )
        let recoveredInitial = try await recoveredScenario.runner.execute(
            CreateReminderProgram(),
            input: input,
            sessionID: "domain-reminder-semantic-recovery"
        )
        let recoveredCheckpoint = try Expect.notNil(
            recoveredInitial.record.checkpoint,
            "authorization race suspends on the Program-authored permission question"
        )
        let recoveredRequest = try Expect.notNil(
            recoveredInitial.record.interactionRequest,
            "authorization-race suspension exposes its interaction request"
        )
        let recoveredPending = try Expect.notNil(
            recoveredRequest.requirement.pendingUserInput,
            "authorization race projects the native Reminders permission question"
        )
        let beforeUserInput = await recoveredScenario.provider
            .counts()

        try Expect.equal(
            recoveredInitial.record.outcome,
            .suspended,
            "authorization race suspends for user intent before requesting OS access"
        )
        try Expect.equal(
            recoveredRequest.kind,
            .user_input,
            "semantic recovery uses native user input rather than approval"
        )
        try Expect.equal(
            recoveredPending.prompt,
            "Allow Agentic to request Reminders access from macOS?",
            "semantic recovery exposes the same production permission question"
        )
        try Expect.equal(
            beforeUserInput.createCalls,
            1,
            "authorization race records exactly one failed not-applied creation before asking"
        )
        try Expect.equal(
            beforeUserInput.accessRequests,
            0,
            "semantic recovery does not request OS access before user confirmation"
        )
        try Expect.equal(
            beforeUserInput.creations,
            0,
            "failed not-applied creation and suspended user input produce no reminder"
        )

        let recovered = try await recoveredScenario.runner.resume(
            CreateReminderProgram(),
            from: recoveredCheckpoint,
            interaction: AgentInteraction.Response(
                request: recoveredRequest,
                resolution: .user_input(
                    .confirmation(true)
                )
            )
        )
        let recoveredOutput = try Expect.notNil(
            recovered.output,
            "authorization race is semantically recovered by CreateReminderProgram"
        )
        let recoveredCounts = await recoveredScenario.provider
            .counts()
        let failedCreateStep = try Expect.notNil(
            recovered.record.steps.first { step in
                guard case .tool(let identifier) = step.kind else {
                    return false
                }

                return identifier
                    == RemindersCreateTool.toolIdentifier
                    && step.failure != nil
            },
            "first reminder creation failure remains visible in the Program trace"
        )
        let propagatedRecovery = try Expect.notNil(
            failedCreateStep.recovery,
            "classified authorization race preserves its propagated recovery evidence"
        )

        try Expect.equal(
            recovered.record.outcome,
            .succeeded,
            "Program succeeds after its explicitly authored semantic authorization route"
        )
        try Expect.equal(
            recoveredOutput.title,
            input.title,
            "semantic recovery returns the actual created reminder"
        )
        try Expect.equal(
            recoveredCounts.createCalls,
            2,
            "one failed not-applied creation is followed by exactly one authored retry"
        )
        try Expect.equal(
            recoveredCounts.accessRequests,
            1,
            "authorization is requested exactly once after the raced failure"
        )
        try Expect.equal(
            recoveredCounts.creations,
            1,
            "semantic recovery creates exactly one reminder and never duplicates the failed not-applied attempt"
        )
        try Expect.equal(
            propagatedRecovery.incident.kind,
            .authorization_required,
            "RemindersCreateTool classifies the real domain authorization failure"
        )
        try Expect.equal(
            propagatedRecovery.state.effect,
            .not_applied,
            "authorization failure proves the first reminder mutation was not applied"
        )
        try Expect.equal(
            propagatedRecovery.state.retry,
            .safe,
            "authorization failure is safe for an explicitly authored new attempt"
        )
        try Expect.equal(
            propagatedRecovery.outcome,
            .propagated,
            "Runtime propagates rather than mechanically retrying the domain failure"
        )
        try Expect.equal(
            propagatedRecovery.plan == nil,
            true,
            "classification alone does not manufacture a mechanical recovery plan"
        )
        try Expect.equal(
            propagatedRecovery.attempts.count,
            0,
            "classification alone performs no mechanical recovery attempts"
        )

        let unrelatedScenario = try ReminderSemanticRecoveryScenario(
            mode: .unrelatedFailure
        )
        let unrelated = try await unrelatedScenario.runner.execute(
            CreateReminderProgram(),
            input: input,
            sessionID: "domain-reminder-unrelated-failure"
        )
        let unrelatedCounts = await unrelatedScenario.provider
            .counts()
        let unrelatedFailedStep = try Expect.notNil(
            unrelated.record.steps.first { step in
                guard case .tool(let identifier) = step.kind else {
                    return false
                }

                return identifier
                    == RemindersCreateTool.toolIdentifier
                    && step.failure != nil
            },
            "unrelated reminder creation failure remains visible in the Program trace"
        )

        try Expect.equal(
            unrelated.record.outcome,
            .failed,
            "unrelated domain failure propagates instead of entering authorization recovery"
        )
        try Expect.equal(
            unrelatedCounts.createCalls,
            1,
            "unrelated failure is never retried semantically"
        )
        try Expect.equal(
            unrelatedCounts.accessRequests,
            0,
            "unrelated failure never requests Reminders authorization"
        )
        try Expect.equal(
            unrelatedCounts.creations,
            0,
            "unrelated failed mutation creates no reminder"
        )
        try Expect.equal(
            unrelatedFailedStep.recovery == nil,
            true,
            "unclassified failure does not invent recovery evidence"
        )

        return [
            .field(
                "recovered_outcome",
                recovered.record.outcome.rawValue
            ),
            .field(
                "recovered_create_calls",
                String(recoveredCounts.createCalls)
            ),
            .field(
                "recovered_access_requests",
                String(recoveredCounts.accessRequests)
            ),
            .field(
                "recovered_creations",
                String(recoveredCounts.creations)
            ),
            .field(
                "recovery_kind",
                propagatedRecovery.incident.kind.rawValue
            ),
            .field(
                "recovery_effect",
                propagatedRecovery.state.effect.rawValue
            ),
            .field(
                "recovery_retry",
                propagatedRecovery.state.retry.rawValue
            ),
            .field(
                "recovery_outcome",
                propagatedRecovery.outcome.rawValue
            ),
            .field(
                "unrelated_outcome",
                unrelated.record.outcome.rawValue
            ),
            .field(
                "unrelated_create_calls",
                String(unrelatedCounts.createCalls)
            ),
        ]
    }
}
