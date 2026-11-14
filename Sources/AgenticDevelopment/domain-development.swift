import Agentic

/// Language-agnostic development agents: an orchestrator that decomposes
/// work into contracted tasks, a worker that implements them, a read-only
/// scout that gathers cited facts, and a read-only reviewer that judges
/// attempts against their contracts.
///
/// Agents declare only a route purpose; the application binds models.
/// Language tooling (Swift today) is available, not assumed.
@Domain
public enum Development {}
