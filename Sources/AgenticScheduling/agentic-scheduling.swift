import Agentic

/// Provider-neutral scheduling: busy time, conflicts, slot search and travel
/// feasibility over any number of calendar sources.
///
/// Every time computation is deterministic and lives in tools; agents turn
/// intent into typed requirements and judge the scored candidates. Sources,
/// participants, places and travel are supplied by the application through
/// `Scheduling.Runtime` in the session's tool services.
@Domain("schedule", aliases: ["scheduling"])
public enum Scheduling {}
