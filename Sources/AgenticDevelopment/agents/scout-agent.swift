import Agentic
import AgenticIO
import AgenticStandard
import AgenticSwift
import Macros
import Schema

public extension Development.Agents {
    @Agent
    enum Scout {
        /// How well a finding is established.
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
            /// One fact, stated plainly.
            public let statement: String
            /// `path:line` references supporting the statement; cite, do not paste.
            public let evidence: [String]
            /// How well the fact is established.
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
            /// Answers to the questions, one fact each.
            public let findings: [Finding]
            /// `path:line` locations a change would likely touch.
            public let candidateSites: [String]
            /// Questions that could not be settled, and why.
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
                those. Do not plan, design, or propose implementations. Your \
                request's fields:
                \(SchemaInstructionText.fields(of: Input.self))
                """
            ),
            .instruction(Development.Instructions.ReadOnly.definition),
            .instruction(Development.Instructions.SourceInspection.definition),
            .text(
                """
                OUTPUT

                \(SchemaInstructionText.fields(of: Output.self))

                Each finding:
                \(SchemaInstructionText.fields(of: Finding.self))

                Confidence, marked honestly:
                \(SchemaInstructionText.values(of: Confidence.self))

                SWIFT DISCOVERY

                For a question about a Swift symbol and what depends on it, run \
                \(SwiftLang.Programs.MapChangeImpact.definition.identifier.rawValue) \
                first. It maps related declarations deterministically and reports \
                what it does not cover. Follow its coverage notes: text-search \
                the names it lists to catch string, reflective, and cross-package \
                references. For one declaration use \
                \(SwiftLang.Tools.ReadSymbol.identifier.rawValue); for a file's \
                outline, \(SwiftLang.Tools.ReadStructure.identifier.rawValue).

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

            SystemIO.Tools.Search.identifier,
            SystemIO.Tools.Find.identifier,
            SystemIO.Tools.Read.identifier,

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
