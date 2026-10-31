import Agentic
import AgenticIO
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
            /// Explicit one-based UTF-16 location (legacy selection mode).
            public let line: Int?
            public let utf16Column: Int?
            /// Exact hierarchical names returned by inspect_swift_document_symbols.
            /// Overloads or duplicate paths are rejected rather than guessed.
            public let symbolPath: [String]?
            /// Optional USR to verify the compiler-resolved symbol identity.
            public let expectedUSR: String?
            /// Opt-in, bounded workspace index synchronization and reference checks.
            public let requireIndexedReferences: Bool
            /// Explicit files that must contain compiler-generated rename edits.
            public let expectedAffectedPaths: [String]
            public let newName: String

            public init(
                path: String,
                newName: String,
                line: Int? = nil,
                utf16Column: Int? = nil,
                symbolPath: [String]? = nil,
                expectedUSR: String? = nil,
                requireIndexedReferences: Bool = false,
                expectedAffectedPaths: [String] = []
            ) {
                self.path = path
                self.line = line
                self.utf16Column = utf16Column
                self.symbolPath = symbolPath
                self.expectedUSR = expectedUSR
                self.requireIndexedReferences = requireIndexedReferences
                self.expectedAffectedPaths = expectedAffectedPaths
                self.newName = newName
            }
        }

        @JSONSchema
        public struct Output: Codable, Sendable, Hashable {
            /// Opaque, short-lived reference; only this identifier is accepted by rename_swift.
            public let proposalID: UUID
            /// Compiler-produced preview for inspection only, not for replay.
            public let proposal: SwiftSemanticRenameResult

            public init(proposalID: UUID, proposal: SwiftSemanticRenameResult) {
                self.proposalID = proposalID
                self.proposal = proposal
            }
        }

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
            try validateSelection(input)
            // A rename may inspect and propose edits across the package.
            // Review access is therefore package-wide, not limited to the
            // source location used to identify the symbol.
            return try SwiftSemanticToolSupport.preflight(
                context: context.workspace,
                toolName: Self.definition.identifier.rawValue,
                risk: Self.risk,
                summary: "Request a compiler-resolved cross-file Swift rename in \(input.path) to '\(input.newName)'. No source files will be modified."
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
            try validateSelection(input)
            let workspace = await SwiftSemanticToolSupport.semanticWorkspace(
                for: execution
            )
            let position: SwiftSemanticPosition
            if let symbolPath = input.symbolPath {
                let symbols = try await workspace.documentSymbols(for: file)
                let matches = selectionPositions(in: symbols, path: symbolPath)
                guard matches.count == 1, let selected = matches.first else {
                    throw failure("Compiler document symbol path is missing or ambiguous: \(symbolPath.joined(separator: " / "))")
                }
                position = selected
            } else if let line = input.line, let column = input.utf16Column {
                position = try SwiftSemanticToolSupport.position(
                    line: line,
                    utf16Column: column,
                    toolName: Self.definition.identifier.rawValue
                )
            } else {
                throw failure("Invalid coordinate selector.")
            }
            if let expectedUSR = input.expectedUSR {
                let resolved = try await workspace.symbolInfo(in: file, at: position)
                guard resolved.contains(where: { $0.identifier == expectedUSR }) else {
                    throw failure("Compiler symbol identity did not match expected USR.")
                }
            }
            let indexedReferences: [SwiftSemanticLocation]
            if input.requireIndexedReferences {
                try await workspace.synchronizeIndex(timeoutSeconds: 30)
                indexedReferences = try await workspace.references(
                    in: file,
                    at: position,
                    includeDeclaration: true
                )
                guard !indexedReferences.isEmpty else {
                    throw failure("Indexed reference query returned no locations; refusing an unverified cross-file rename.")
                }
            } else {
                indexedReferences = []
            }
            let proposal = try await workspace.rename(
                in: file,
                at: position,
                to: input.newName
            )

            guard proposal.documents.contains(where: { !$0.edits.isEmpty }) else {
                throw failure("SourceKit-LSP returned no rename edits.")
            }
            for reference in indexedReferences {
                let matched = proposal.documents.contains { document in
                    document.uri.standardizedFileURL == reference.uri.standardizedFileURL
                        && document.edits.contains { edit in
                            contains(reference.range.start, in: edit.range)
                        }
                }
                guard matched else {
                    throw failure("SourceKit-LSP rename omits an indexed reference at \(reference.uri.path):\(reference.range.start.line):\(reference.range.start.utf16Column). No proposal retained.")
                }
            }
            for expectedPath in input.expectedAffectedPaths {
                let expectedFile = try sourceFile(expectedPath, execution: execution)
                guard proposal.documents.contains(where: {
                    $0.uri.standardizedFileURL == expectedFile && !$0.edits.isEmpty
                }) else {
                    throw failure("SourceKit-LSP rename omitted required affected file \(expectedPath). No proposal retained.")
                }
            }

            let rootComponents = execution.projectRoot
                .resolvingSymlinksInPath().pathComponents
            var sources: [URL: String] = [:]
            for document in proposal.documents {
                let target = document.uri.standardizedFileURL
                guard target.isFileURL,
                    target.pathExtension == "swift",
                    target.resolvingSymlinksInPath() == target,
                    target.pathComponents.starts(with: rootComponents) else {
                    throw failure(
                        "Rename proposal contains an unsupported or out-of-workspace document: \(document.uri.absoluteString)"
                    )
                }
                _ = try FileToolAccess.authorize(
                    workspace: execution.workspace,
                    rootID: execution.workspace.rootIdentifier,
                    path: target.path,
                    capability: .read,
                    toolName: Self.definition.identifier.rawValue
                )
                sources[target] = try String(contentsOf: target, encoding: .utf8)
            }
            let proposalID = await SwiftRenameProposalStore.shared.retain(
                proposal,
                workspace: execution.workspace,
                sources: sources
            )
            return Output(proposalID: proposalID, proposal: proposal)
        }

        private func validateSelection(_ input: Input) throws {
            let hasCoordinate = input.line != nil && input.utf16Column != nil
            let hasSymbol = input.symbolPath != nil
            guard hasCoordinate != hasSymbol,
                (input.line == nil) == (input.utf16Column == nil),
                !input.newName.isEmpty,
                input.expectedAffectedPaths.allSatisfy({ !$0.isEmpty }) else {
                throw failure("Provide either line+utf16Column or a symbolPath, and a nonempty newName.")
            }
            if let symbolPath = input.symbolPath {
                guard !symbolPath.isEmpty,
                    symbolPath.allSatisfy({ !$0.isEmpty }) else {
                    throw failure("symbolPath must contain nonempty compiler document-symbol names.")
                }
            } else if let line = input.line, let column = input.utf16Column {
                _ = try SwiftSemanticToolSupport.position(
                    line: line,
                    utf16Column: column,
                    toolName: Self.definition.identifier.rawValue
                )
            }
        }

        private func contains(
            _ position: SwiftSemanticPosition,
            in range: SwiftSemanticRange
        ) -> Bool {
            let afterStart = position.line > range.start.line
                || (position.line == range.start.line
                    && position.utf16Column >= range.start.utf16Column)
            let beforeEnd = position.line < range.end.line
                || (position.line == range.end.line
                    && position.utf16Column < range.end.utf16Column)
            return afterStart && beforeEnd
        }

        private func selectionPositions(
            in symbols: [SwiftSemanticDocumentSymbol],
            path: [String]
        ) -> [SwiftSemanticPosition] {
            guard let name = path.first else { return [] }
            return symbols.filter { $0.name == name }.flatMap { symbol in
                if path.count == 1 {
                    return [symbol.selectionRange.start]
                }
                return selectionPositions(
                    in: symbol.children,
                    path: Array(path.dropFirst())
                )
            }
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
