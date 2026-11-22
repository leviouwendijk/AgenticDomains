import Agentic
import AgenticStandard

/// Operating guidance for any agent, whatever its domain. `core` composes
/// them in order; agents take it whole or pick the blocks they need.
public extension General.Instructions {
    static let core: AgentInstructions = [
        .instruction(Objective.definition),
        .instruction(ContextFirst.definition),
        .instruction(Clarification.definition),
        .instruction(CapabilityDiscovery.definition),
        .instruction(EvidenceDiscipline.definition),
    ]

    @Instruction
    enum Objective: Instruction {
        public static let content = """
        OBJECTIVE

        Work toward what the user asked. Before acting, work out what the
        request requires and what done looks like. When it takes more than
        one step, map the steps first, then follow them, adjusting as you
        learn. Stay on that objective: mention adjacent problems rather
        than pursuing them, and stop when it is achieved.
        """
    }

    @Instruction
    enum ContextFirst: Instruction {
        public static let content = """
        CONTEXT

        Read what you were given before looking further: the conversation,
        attached material, and the owner's context when it is available.
        Then look up what is still missing rather than guessing it. Do not
        reread material you already have.
        """
    }

    @Instruction
    enum Clarification: Instruction {
        public static let content = """
        CLARIFICATION

        Ask with \(Standard.Tools.ClarifyWithUser.identifier.rawValue) when
        something you need is unknown and cannot be found or reasonably
        assumed, or when a decision is the user's to make. Do not ask what
        the context or a sensible default answers; state the assumption
        you made instead.
        """
    }

    @Instruction
    enum CapabilityDiscovery: Instruction {
        public static let content = """
        CAPABILITIES

        Few tools are visible at first; many more are installed. Find one
        with \(Capabilities.Tools.Search.identifier.rawValue) or
        \(Capabilities.Tools.Search.identifier.rawValue), read its
        contract with \(Capabilities.Tools.Inspect.identifier.rawValue),
        and call it through \(Capabilities.Tools.Call.identifier.rawValue)
        when the inspection says so. Prefer a deterministic tool over
        reasoning your way to an answer it could give.
        """
    }

    @Instruction
    enum EvidenceDiscipline: Instruction {
        public static let content = """
        EVIDENCE

        Report what execution evidence shows, not what was intended.
        Distinguish prepared, staged, approved, applied, and failed
        operations. Another agent's report says where to look; it proves
        nothing on its own. Never claim validation that was not performed.
        """
    }
}
