import AgenticInference
import AgenticPrograms
import AgenticSwift
import Foundation
import TestFlows

private enum SwiftChangeProgramFixtureError: Error {
    case unexpectedInference(String)
    case unexpectedInferenceSite(String)
}

private struct SwiftChangeInferenceSnapshot: Sendable {
    let sites: [String]
    let understandingInputs: [SwiftChangeContext]
    let planningInputs: [SwiftChangePlanningInput]
}

private actor SwiftChangeInferenceFixture:
    AgentInferenceInvoking
{
    private var receivedSites: [String] = []
    private var receivedUnderstandingInputs: [SwiftChangeContext] = []
    private var receivedPlanningInputs: [SwiftChangePlanningInput] = []

    func infer<Inference: AgentInference>(
        _ inference: Inference.Type,
        at site: AgentInferenceSiteIdentifier,
        input: Inference.Input
    ) async throws -> Inference.Output {
        receivedSites.append(site.rawValue)

        if inference.definition.identifier
            == UnderstandSwiftChange.definition.identifier
        {
            guard site == PlanSwiftChangeProgram.understandingSite else {
                throw SwiftChangeProgramFixtureError.unexpectedInferenceSite(
                    site.rawValue
                )
            }

            let encodedInput = try JSONEncoder().encode(input)
            let typedInput = try JSONDecoder().decode(
                SwiftChangeContext.self,
                from: encodedInput
            )

            receivedUnderstandingInputs.append(typedInput)

            let output = SwiftChangeUnderstanding(
                summary: "The supplied evidence describes a change to typed Program composition.",
                affectedAreas: [
                    "AgenticSwift",
                    "AgenticPrograms",
                ],
                risks: [
                    "Typed inference handoff could regress if outputs are lowered prematurely.",
                ],
                uncertainties: [
                    "Host composition is intentionally outside this Domain-only pass.",
                ]
            )
            let encodedOutput = try JSONEncoder().encode(output)

            return try JSONDecoder().decode(
                Inference.Output.self,
                from: encodedOutput
            )
        }

        if inference.definition.identifier
            == PlanSwiftChange.definition.identifier
        {
            guard site == PlanSwiftChangeProgram.planningSite else {
                throw SwiftChangeProgramFixtureError.unexpectedInferenceSite(
                    site.rawValue
                )
            }

            let encodedInput = try JSONEncoder().encode(input)
            let typedInput = try JSONDecoder().decode(
                SwiftChangePlanningInput.self,
                from: encodedInput
            )

            receivedPlanningInputs.append(typedInput)

            let output = SwiftChangePlan(
                steps: [
                    SwiftChangeStep(
                        title: "Implement typed composition",
                        rationale: typedInput.understanding.summary
                    ),
                ],
                verification: [
                    "swift build",
                    "swift run domtest --verbose",
                ],
                caveats: typedInput.understanding.uncertainties
            )
            let encodedOutput = try JSONEncoder().encode(output)

            return try JSONDecoder().decode(
                Inference.Output.self,
                from: encodedOutput
            )
        }

        throw SwiftChangeProgramFixtureError.unexpectedInference(
            inference.definition.identifier.rawValue
        )
    }

    func snapshot() -> SwiftChangeInferenceSnapshot {
        SwiftChangeInferenceSnapshot(
            sites: receivedSites,
            understandingInputs: receivedUnderstandingInputs,
            planningInputs: receivedPlanningInputs
        )
    }
}

extension AgenticDomainsFlowTesting {
    static func runSwiftChangeProgram() async throws
        -> [TestFlowDiagnostic]
    {
        let inference = SwiftChangeInferenceFixture()
        var registry = ProgramRegistry()

        try AgenticSwiftProgramSet().register(
            into: &registry
        )

        try Expect.equal(
            registry.count,
            1,
            "AgenticSwift Program set registers the multi-inference Swift change Program"
        )
        try Expect.equal(
            registry.descriptors.first?.identifier.rawValue ?? "",
            "swift.plan_change",
            "AgenticSwift exposes the Swift change Program through ProgramRegistry"
        )

        let input = SwiftChangeContext(
            objective: "Add a typed multi-inference Swift Program proof.",
            evidence: [
                "AgentProgramContext can invoke inference sites by semantic identifier.",
                "The first inference output should remain typed when supplied to the second inference.",
            ],
            constraints: [
                "Do not add a new inference strategy kind.",
                "Keep Host composition outside this pass.",
            ]
        )
        let output = try await PlanSwiftChangeProgram().run(
            input,
            in: AgentProgramContext(
                inference: inference
            )
        )
        let snapshot = await inference.snapshot()

        try Expect.equal(
            snapshot.sites.count,
            2,
            "PlanSwiftChangeProgram performs exactly two semantic inference operations"
        )
        try Expect.equal(
            snapshot.sites.first ?? "",
            PlanSwiftChangeProgram.understandingSite.rawValue,
            "PlanSwiftChangeProgram invokes understanding first"
        )
        try Expect.equal(
            snapshot.sites.last ?? "",
            PlanSwiftChangeProgram.planningSite.rawValue,
            "PlanSwiftChangeProgram invokes planning second"
        )
        try Expect.equal(
            snapshot.understandingInputs.first?.objective ?? "",
            input.objective,
            "UnderstandSwiftChange receives the original typed objective"
        )
        try Expect.equal(
            snapshot.planningInputs.first?.understanding.summary ?? "",
            "The supplied evidence describes a change to typed Program composition.",
            "PlanSwiftChange receives the typed output produced by UnderstandSwiftChange"
        )
        try Expect.equal(
            snapshot.planningInputs.first?.constraints.first ?? "",
            input.constraints.first ?? "",
            "PlanSwiftChange retains the original Program constraints"
        )
        try Expect.equal(
            output.understanding.affectedAreas.first ?? "",
            "AgenticSwift",
            "Program output preserves the typed understanding"
        )
        try Expect.equal(
            output.plan.steps.first?.title ?? "",
            "Implement typed composition",
            "Program output preserves the second typed inference result"
        )
        try Expect.equal(
            output.plan.steps.first?.rationale ?? "",
            output.understanding.summary,
            "Second inference result is concretely derived from the first typed inference output"
        )
        try Expect.equal(
            output.plan.verification.count,
            2,
            "Swift change plan carries explicit verification steps"
        )

        return [
            .field(
                "program",
                PlanSwiftChangeProgram.descriptor.identifier.rawValue
            ),
            .field(
                "inference_calls",
                "\(snapshot.sites.count)"
            ),
            .field(
                "first_site",
                snapshot.sites.first ?? ""
            ),
            .field(
                "second_site",
                snapshot.sites.last ?? ""
            ),
        ]
    }
}
