import Agentic
import AgenticIO
import AgenticStandard

/// Shared guidance for Development agents. Each agent composes the blocks
/// it needs, and runs record which revision they used. The task contract
/// vocabulary itself lives in `Tasks.Instructions.Contract`; evidence
/// discipline in `General.Instructions.EvidenceDiscipline`.
public extension Development.Instructions {
    @Instruction
    enum NarrowScope: Instruction {
        public static let content = """
        SCOPE

        Work narrowly on the stated objective. Do not expand into unrelated
        architecture, cleanup, investigation, or speculative improvements.

        Builds, test runs, product execution, commits, pushes, and other
        repository operations happen only when explicitly requested.

        Do not assume shell tools such as rg, grep, find, sed, or bash are
        available; use the provided tools.

        Respect all preflight and approval requirements. When a needed
        capability is not visible, find it with
        \(Standard.Tools.SearchCapabilities.identifier.rawValue); never bypass
        a restriction.
        """
    }

    @Instruction
    enum SourceInspection: Instruction {
        public static let content = """
        INSPECTION

        Search before reading, with these tools rather than the shell:
            \(SystemIO.Tools.SearchSources.identifier.rawValue): query (literal) or pattern (regex); hits show their lines
            \(SystemIO.Tools.SearchFilepaths.identifier.rawValue)
            \(SystemIO.Tools.ScanFilepaths.identifier.rawValue)
        Often the hit's lines answer the question. Otherwise read the
        narrowest range that does with
        \(SystemIO.Tools.ReadSelection.identifier.rawValue); read several
        files or windows in one call with
        \(SystemIO.Tools.ReadFiles.identifier.rawValue) and its reads.
        Do not reread material just to confirm it.
        """
    }

    @Instruction
    enum ReadOnly: Instruction {
        public static let content = """
        READ-ONLY

        You never mutate the workspace and have no tools that could. When
        the answer requires a change, describe it; do not attempt it.
        """
    }
}
