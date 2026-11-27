import Agentic
import Foundation
import Loa
import Macros
import Primitives
import Schema

public extension LoaLang.Programs {
    /// Runs a Loa program against the installed tools.
    @Program
    struct Run {
        @JSONSchema
        public struct Input: HashableSource {
            /// The Loa source: statements, pages, or a one-liner such as `git.status();`.
            public let source: String
            /// Runs of the same goal build on each other: completed reads are reused and a
            /// completed mutation is never repeated. Defaults to `default`.
            public let goal: String?

            public init(source: String, goal: String? = nil) {
                self.source = source
                self.goal = goal
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            /// `completed`, `failed`, `suspended` (waits for the owner) or `invalid` (did
            /// not parse or check; nothing ran).
            public let status: String
            /// What stopped the run, with line and column.
            public let message: String?
            /// Checker errors and warnings, one per line.
            public let diagnostics: [String]
            /// Each page's bindings (`_` for top-level statements), as JSON.
            public let values: JSONValue
            /// What each call did in this run: `mail.search ran`, `mail.accounts reused`, …
            public let calls: [String]
        }

        public static let purpose = """
        Run a Loa program: compose the installed tools as calls in one program instead of \
        one tool call per step. Read the catalog with loa_program_reference first. Reads \
        already done in the same goal are reused; a completed mutation is never repeated.
        """

        let catalog: Loa.Catalog
        let ledgers: LoaLedgers

        /// `catalog` from the installed tools (`Loa.Catalog(tools:domains:)`).
        public init(catalog: Loa.Catalog, ledgers: LoaLedgers) {
            self.catalog = catalog
            self.ledgers = ledgers
        }

        public func run(_ input: Input, in context: ProgramContext) async throws -> Output {
            let goal = input.goal ?? "default"
            let result: Loa.RunResult
            do {
                result = try await Loa.run(
                    input.source,
                    catalog: catalog,
                    executor: ProgramContextExecutor(context: context),
                    ledger: await ledgers.ledger(for: goal)
                )
            } catch let failure as Loa.SyntaxFailure {
                return Output(status: "invalid", message: failure.description, diagnostics: [], values: .object([:]), calls: [])
            } catch let failure as Loa.CheckFailure {
                return Output(
                    status: "invalid",
                    message: "The program did not check; nothing ran.",
                    diagnostics: failure.diagnostics.map(\.description),
                    values: .object([:]),
                    calls: []
                )
            }
            await ledgers.store(result.ledger, for: goal)
            if let interruption = result.interruption {
                throw interruption
            }

            var values: [String: JSONValue] = [:]
            for (page, record) in result.pages {
                values[page] = JSONValue(loa: .record(record))
            }
            if !result.bindings.fields.isEmpty {
                values["_"] = JSONValue(loa: .record(result.bindings))
            }
            let status = result.failure != nil ? "failed" : result.suspension != nil ? "suspended" : "completed"
            return Output(
                status: status,
                message: result.failure?.description ?? result.suspension?.description,
                diagnostics: [],
                values: .object(values),
                calls: Self.calls(result.ledger.entries(run: result.run))
            )
        }

        /// One line per call of this run.
        static func calls(_ entries: [Loa.LedgerEntry]) -> [String] {
            entries.compactMap { entry in
                switch entry.kind {
                case .completed(let call, _): "\(call.function) ran"
                case .reused(let call, _, _): "\(call.function) reused"
                case .failed(let call, let message): "\(call.function) failed: \(message)"
                case .not_run(let call, let message): "\(call.function) did not run: \(message)"
                case .unknown(let call, let message): "\(call.function) outcome unknown: \(message)"
                case .settled(let call, let done, _, let by): "\(call.function) settled \(done ? "done" : "not done") by \(by.rawValue)"
                case .released(let call, _, let reason): "\(call.function) released\(reason.map { ": \($0)" } ?? "")"
                case .pending(let call, let message): "\(call.function) pending: \(message)"
                case .answered(let call, _): "\(call.function) answered"
                case .intended, .asked, .bound: nil
                }
            }
        }
    }

    /// Checks a Loa program without running it.
    @Program
    struct Check {
        @JSONSchema
        public struct Input: HashableSource {
            /// The Loa source to check.
            public let source: String

            public init(source: String) {
                self.source = source
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            /// No errors: the program can run.
            public let valid: Bool
            /// Errors and warnings with line and column, the closest match and the signature.
            public let diagnostics: [String]
            /// Each call with an effect, in source order: `mail.send external (loop)`.
            public let effects: [String]
        }

        public static let purpose = """
        Check a Loa program without running it: names, calls and arguments against the \
        catalog, types, and the effects it would have.
        """

        let catalog: Loa.Catalog

        public init(catalog: Loa.Catalog) {
            self.catalog = catalog
        }

        public func run(_ input: Input, in context: ProgramContext) async throws -> Output {
            do {
                let result = try Loa.check(input.source, catalog: catalog)
                return Output(
                    valid: result.isValid,
                    diagnostics: result.diagnostics.map(\.description),
                    effects: result.effects.filter { $0.effect != .pure }.map { effect in
                        "\(effect.function) \(effect.effect.rawValue)\(effect.inLoop ? " (loop)" : "")"
                    }
                )
            } catch let failure as Loa.SyntaxFailure {
                return Output(valid: false, diagnostics: [failure.description], effects: [])
            }
        }
    }

    /// The catalog a Loa program may call, as signatures.
    @Program
    struct Reference {
        @JSONSchema
        public struct Input: HashableSource {
            /// Only these domains; all when empty or omitted.
            public let domains: [String]?

            public init(domains: [String]? = nil) {
                self.domains = domains
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            /// One signature per line, grouped by domain, then the named types.
            public let reference: String
        }

        public static let purpose = """
        The functions a Loa program may call, one signature per line with its effect, \
        grouped by domain. Read it before writing a program.
        """

        let catalog: Loa.Catalog

        public init(catalog: Loa.Catalog) {
            self.catalog = catalog
        }

        public func run(_ input: Input, in context: ProgramContext) async throws -> Output {
            var selected = catalog
            if let domains = input.domains, !domains.isEmpty {
                selected.domains = catalog.domains.filter { domain in
                    domains.contains(domain.name) || domain.aliases.contains(where: domains.contains)
                }
            }
            return Output(reference: selected.reference())
        }
    }
}
