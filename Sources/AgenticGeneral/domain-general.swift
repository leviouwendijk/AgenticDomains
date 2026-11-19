import Agentic

/// Task-neutral agents and the operating guidance any agent can compose:
/// understand the request, read context first, clarify only what cannot be
/// found, discover capabilities on demand, report from evidence.
///
/// Applications fork `General.Agents.GeneralPurpose` and add their domains.
@Domain
public enum General {}
