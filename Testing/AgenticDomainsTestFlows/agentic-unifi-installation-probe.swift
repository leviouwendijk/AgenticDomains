import Agentic

/// Test-only installation sink. Production registration remains macro-derived.
final class UniFiInstallationProbe: DomainInstallation.Sink {
    private(set) var registry = ToolRegistry()
    private(set) var registration_errors = 0

    func install<T: Tool>(
        _ tool: T,
        modelContract: ToolModelContract?
    ) {
        do {
            try registry.register(tool, modelContract: modelContract)
        } catch {
            registration_errors += 1
        }
    }

    func install<P: Program>(
        _ program: P,
        realization: ProgramRealization<P>?
    ) {
        _ = program
        _ = realization
    }

    func install<I: Inference>(_ inference: I.Type) {
        _ = inference
    }

    func install<A: Agent>(_ agent: A.Type) {
        _ = agent
    }

    func install<A: InferenceAdapter>(_ adapter: A) {
        _ = adapter
    }

    func install<A: InferenceAdapterFor>(_ adapter: A) {
        _ = adapter
    }
}
