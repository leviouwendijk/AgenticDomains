import Agentic
import AgenticIO
import AgenticStandard
import AgenticSwift
import Macros
import Schema

public extension Development.Agents {
    @Agent
    enum Scout {
        @JSONSchema
        public enum Confidence: String, Sendable, Codable, Hashable, CaseIterable {
            /// Read directly in source or reported by a compiler graph.
            case verified
            /// Inferred from strong but indirect evidence.
            case likely
            /// A guess worth checking.
            case unverified
        }

        @JSONSchema
        public struct Finding: HashableResult {
            public let statement: String
            /// `path:line` references supporting the statement.
            public let evidence: [String]
            public let confidence: Confidence
        }

        @JSONSchema
        public struct Input: HashableSource {
            /// The specific questions to answer.
            public let questions: [String]
            /// Paths to search within; empty means the whole workspace scope.
            public let scope: [String]?
            /// Facts the caller already holds, so they are not re-established.
            public let knownFacts: [String]?

            public init(
                questions: [String],
                scope: [String]? = nil,
                knownFacts: [String]? = nil
            ) {
                self.questions = questions
                self.scope = scope
                self.knownFacts = knownFacts
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let findings: [Finding]
            /// `path:line` locations likely to need change.
            public let candidateSites: [String]
            public let uncertainties: [String]
            /// What was searched and, as importantly, what was not.
            public let coverage: [String]
        }

        public static let purpose = """
        Read-only fact gathering: answers specific questions about the workspace \
        with cited findings, candidate change sites, and explicit coverage, so \
        the caller receives facts instead of file contents.
        """

        public static let instructions: AgentInstructions = [
            .text(
                """
                You are a read-only scout operating under the Development \
                orchestrator. Answer the questions you were given, and only \
                those. Do not plan, design, or propose implementations. Stay \
                inside the given scope and skip facts listed in knownFacts.
                """
            ),
            .instruction(Development.Instructions.ReadOnly.definition),
            .instruction(Development.Instructions.SourceInspection.definition),
            .text(
                """
                FINDINGS

                Each finding is one fact with evidence as path:line references. \
                Mark confidence honestly: verified when you read it in source or \
                a compiler graph reported it; likely for strong indirect \
                evidence; unverified for a guess worth checking. Cite source; \
                do not paste it.

                SWIFT DISCOVERY

                For a question about a Swift symbol and what depends on it, run \
                \(SwiftLang.Programs.MapChangeImpact.definition.identifier.rawValue) \
                first. It maps related declarations deterministically and reports \
                what it does not cover. Follow its coverage notes: text-search \
                the names it lists to catch string, reflective, and cross-package \
                references. For one declaration use \
                \(SwiftLang.Tools.ReadSymbol.identifier.rawValue); for a file's \
                outline, \(SwiftLang.Tools.ReadStructure.identifier.rawValue).

                OUTPUT

                candidateSites: path:line locations a change would likely touch.
                uncertainties: questions you could not settle, and why.
                coverage: what you searched, and what you deliberately did not.

                Stop once the questions are answered or cannot be answered further.
                """
            ),
        ]

        // Read-only by construction: nothing that mutates is even available.
        public static let capabilities = AgentCapabilities(
            available: .init(
                tools: .init(
                    members: readTools + [
                        // Called by MapChangeImpact.
                        SwiftLang.Tools.InspectArchitectureRelationships.identifier,
                    ]
                ),
                programs: .init(
                    members: [
                        SwiftLang.Programs.MapChangeImpact.definition.identifier,
                    ]
                )
            ),
            visible: .init(
                tools: .init(
                    members: readTools
                ),
                programs: .init(
                    members: [
                        SwiftLang.Programs.MapChangeImpact.definition.identifier,
                    ]
                )
            )
        )

        private static let readTools: [ToolIdentifier] = [
            Standard.Tools.InspectCapability.identifier,

            SystemIO.Tools.SearchSources.identifier,
            SystemIO.Tools.SearchFilepaths.identifier,
            SystemIO.Tools.ScanFilepaths.identifier,
            SystemIO.Tools.ReadSelection.identifier,
            SystemIO.Tools.ReadFile.identifier,

            SwiftLang.Tools.ReadSymbol.identifier,
            SwiftLang.Tools.ReadStructure.identifier,
            SwiftLang.Tools.ListSymbols.identifier,
            SwiftLang.Tools.SearchArchitecture.identifier,
            SwiftLang.Tools.InspectArchitectureSymbol.identifier,
        ]

        // The model serving `.researcher` is bound by the application.
        public static let modelSelection = AgentModelSelection(
            purpose: .researcher
        )
    }
}
