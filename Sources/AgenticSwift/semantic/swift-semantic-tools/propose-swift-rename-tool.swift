import Agentic
import Foundation
import Macros
import Schema
import SwiftSemantics

public extension SwiftLang.Tools {
    @Tool("propose_swift_rename")
    struct ProposeRename {
        @JSONSchema
        public struct Input: Codable, Sendable, Hashable {
            /// Swift source path relative to the selected package root.
            public let path: String
            /// One-based source line.
            public let line: Int
            /// One-based UTF-16 column.
            public let utf16Column: Int
            /// Requested replacement symbol name.
            public let newName: String

            public init(
                path: String,
                line: Int,
                utf16Column: Int,
                newName: String
            ) {
                self.path = path
                self.line = line
                self.utf16Column = utf16Column
                self.newName = newName
            }
        }

        public typealias Output = SwiftSemanticRenameResult

        public static let purpose =
            "Request an ordered, cross-file Swift symbol rename proposal from SourceKit-LSP without applying edits. Compiler-semantic preparation may execute package tooling. The returned proposal is not approved for publication."

        public static let risk: ActionRisk = .privileged

        public init() {}

        public func preflight(
            _ input: Input,
            in context: ToolContext
        ) async throws -> ToolPreflight {
            let execution = try SwiftSemanticToolSupport.resolve(
                context.workspace,
                toolName: Self.definition.identifier.rawValue
            )
            _ = try sourceFile(input.path, execution: execution)
            _ = try SwiftSemanticToolSupport.position(
                line: input.line,
                utf16Column: input.utf16Column,
                toolName: Self.definition.identifier.rawValue
            )
            // A rename may inspect and propose edits across the package.
            // Review access is therefore package-wide, not limited to the
            // source location used to identify the symbol.
            return try SwiftSemanticToolSupport.preflight(
                context: context.workspace,
                toolName: Self.definition.identifier.rawValue,
                risk: Self.risk,
                summary: "Request cross-file Swift rename proposal at \(input.path):\(input.line):\(input.utf16Column) to '\(input.newName)'. No source files will be modified."
            )
        }

        public func call(
            _ input: Input,
            in context: ToolContext
        ) async throws -> Output {
            let execution = try SwiftSemanticToolSupport.resolve(
                context.workspace,
                toolName: Self.definition.identifier.rawValue
            )
            let file = try sourceFile(input.path, execution: execution)
            let position = try SwiftSemanticToolSupport.position(
                line: input.line,
                utf16Column: input.utf16Column,
                toolName: Self.definition.identifier.rawValue
            )
            let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
                for: execution
            )
            let proposal = try await workspace.rename(
                in: file,
                at: position,
                to: input.newName
            )

            guard proposal.documents.contains(where: { !$0.edits.isEmpty }) else {
                throw failure("SourceKit-LSP returned no rename edits.")
            }

            let rootComponents = execution.projectRoot
                .resolvingSymlinksInPath().pathComponents
            for document in proposal.documents {
                let target = document.uri.standardizedFileURL
                guard target.isFileURL,
                    target.pathExtension == "swift",
                    target.resolvingSymlinksInPath().pathComponents
                        .starts(with: rootComponents) else {
                    throw failure(
                        "Rename proposal contains an unsupported or out-of-workspace document: \(document.uri.absoluteString)"
                    )
                }
            }

            return proposal
        }

        private func sourceFile(
            _ path: String,
            execution: SwiftSemanticToolContext
        ) throws -> URL {
            let file = try execution.projectFile(
                path,
                toolName: Self.definition.identifier.rawValue
            )
            guard file.pathExtension == "swift",
                file.resolvingSymlinksInPath() == file,
                FileManager.default.fileExists(atPath: file.path) else {
                throw failure(
                    "Expected an existing, non-symlink Swift source file inside the selected package: \(path)"
                )
            }
            return file
        }

        private func failure(_ detail: String) -> AgenticSwiftToolError {
            .operationFailed(
                toolName: Self.definition.identifier.rawValue,
                operation: "prepare SourceKit-LSP rename proposal",
                exitCode: nil,
                signal: nil,
                detail: detail
            )
        }
    }
}
