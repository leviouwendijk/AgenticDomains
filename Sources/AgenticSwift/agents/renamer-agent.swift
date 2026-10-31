import Agentic
import AgenticIO
import Macros
import Schema

public extension SwiftLang.Agents {
    @Agent
    enum Renamer {
        @JSONSchema
        public struct Input: HashableSource {
            public let objective: String
            public let candidatePaths: [String]
            public let constraints: [String]

            public init(
                objective: String,
                candidatePaths: [String] = [],
                constraints: [String] = []
            ) {
                self.objective = objective
                self.candidatePaths = candidatePaths
                self.constraints = constraints
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let summary: String
            public let selectedSymbol: String?
            public let proposalID: String?
            public let changedPaths: [String]
            public let verification: [String]
            public let unresolved: [String]

            public init(
                summary: String,
                selectedSymbol: String? = nil,
                proposalID: String? = nil,
                changedPaths: [String] = [],
                verification: [String] = [],
                unresolved: [String] = []
            ) {
                self.summary = summary
                self.selectedSymbol = selectedSymbol
                self.proposalID = proposalID
                self.changedPaths = changedPaths
                self.verification = verification
                self.unresolved = unresolved
            }
        }

        public static let purpose = """
        Rename Swift symbols through compiler-resolved, source-bound proposals and governed publication, without arbitrary file mutation.
        """

        public static let instructions = """
        Perform only the explicitly requested Swift symbol rename.
        Discover candidate files with read and search tools, then inspect compiler document symbols.
        Select exactly one compiler symbol path. Never infer a rename position from textual matches or calculate UTF-16 columns.
        If candidates are ambiguous, incomplete, or truncated, report the uncertainty rather than guessing.
        When a USR is available, use it to verify the proposed symbol identity.
        Use propose_swift_rename to obtain the compiler edits and a proposalID.
        Examine the proposed cross-file changes before calling rename_swift with that exact proposalID.
        Let the existing authorization, review, compiler validation, and Writers publication flow decide whether changes may be applied.
        Never use mutate_files, direct write APIs, or shell commands to perform or repair a rename.
        A proposal is not a completed rename; report actual publication status and any failures.
        """

        public static let capabilities = AgentCapabilities(
            available: .init(
                tools: .init(
                    members: [
                        SystemIO.Tools.ReadFile.identifier,
                        SystemIO.Tools.ReadSelection.identifier,
                        SystemIO.Tools.ScanFilepaths.identifier,
                        SystemIO.Tools.SearchFilepaths.identifier,
                        SystemIO.Tools.SearchSources.identifier,
                        SystemIO.Tools.LoadSearchContext.identifier,
                        SystemIO.Tools.ProveSearchResults.identifier,

                        SwiftLang.Tools.ListSymbols.identifier,
                        SwiftLang.Tools.ReadSymbol.identifier,
                        SwiftLang.Tools.InspectDocumentSymbols.definition.identifier,
                        SwiftLang.Tools.InspectSymbol.definition.identifier,
                        SwiftLang.Tools.FindReferences.definition.identifier,
                        SwiftLang.Tools.ProposeRename.definition.identifier,
                        SwiftLang.Tools.RenameSwift.definition.identifier,
                    ]
                )
            ),
            visible: .init(
                tools: .init(
                    members: [
                        SystemIO.Tools.ReadFile.identifier,
                        SystemIO.Tools.ReadSelection.identifier,
                        SystemIO.Tools.ScanFilepaths.identifier,
                        SystemIO.Tools.SearchFilepaths.identifier,
                        SystemIO.Tools.SearchSources.identifier,
                        SystemIO.Tools.LoadSearchContext.identifier,
                        SystemIO.Tools.ProveSearchResults.identifier,

                        SwiftLang.Tools.ListSymbols.identifier,
                        SwiftLang.Tools.ReadSymbol.identifier,
                        SwiftLang.Tools.InspectDocumentSymbols.definition.identifier,
                        SwiftLang.Tools.InspectSymbol.definition.identifier,
                        SwiftLang.Tools.FindReferences.definition.identifier,
                        SwiftLang.Tools.ProposeRename.definition.identifier,
                        SwiftLang.Tools.RenameSwift.definition.identifier,
                    ]
                )
            )
        )
    }
}
