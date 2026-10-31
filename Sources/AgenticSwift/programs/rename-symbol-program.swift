import Agentic

extension SwiftLang.Programs {
    @Program
    public struct RenameSymbol {
        public typealias Input = SwiftLang.Tools.ProposeRename.Input
        public typealias Output = SwiftLang.Tools.RenameSwift.Output

        public static let purpose = """
        Rename one compiler-resolved Swift symbol by obtaining a source-bound proposal and passing its exact identifier into governed Writers review and publication, without an intermediate model inference.
        """

        public init() {}

        public func run(
            _ input: Input,
            in context: ProgramContext
        ) async throws -> Output {
            let proposal = try await context.invoke(
                SwiftLang.Tools.ProposeRename.definition.identifier,
                input: input,
                as: SwiftLang.Tools.ProposeRename.Output.self
            )

            return try await context.invoke(
                SwiftLang.Tools.RenameSwift.definition.identifier,
                input: SwiftLang.Tools.RenameSwift.Input(
                    proposalID: proposal.proposalID
                ),
                as: Output.self
            )
        }
    }
}
