import Agentic
import Foundation
import Frame
import Macros
import Schema

/// The Frame configuration language as tools: which modules exist, what a
/// module's types accept, and whether a file holds. Modules come from two
/// places: those compiled into the program, supplied by the application as
/// `FrameLang.Modules` in the session's tool services, and the module files
/// editors read (`~/.config/frame/modules`). A compiled module always wins
/// over a file of the same name, so a stale file cannot misreport.
@Domain
public enum FrameLang {}

public extension FrameLang {
    /// What the application compiles in, and where module files live.
    struct Modules: Sendable {
        public let compiled: [Frame.Module]
        public let directory: URL

        public init(
            compiled: [Frame.Module],
            directory: URL = Frame.modulesDirectory
        ) {
            self.compiled = compiled
            self.directory = directory
        }
    }

    @JSONSchema
    enum Origin: String, Sendable, Codable, Hashable, CaseIterable {
        /// Compiled into the program: exactly what it decodes.
        case program
        /// Only a module file: its schema, as last written.
        case file
    }

    /// Every module a document may import, by origin.
    struct Catalog: Sendable {
        public struct Entry: Sendable {
            public let module: Frame.Module
            public let origin: Origin
            /// A compiled module whose file differs from it.
            public let staleFile: Bool
        }

        public let entries: [Entry]
        public let directory: URL
        public let failures: [String]

        public var environment: Frame.Environment {
            .init([Frame.Module.frame] + entries.map(\.module))
        }

        public func entry(named name: String) -> Entry? {
            entries.first { $0.module.name == name }
        }

        public init(_ modules: Modules) {
            let loaded = Frame.Environment.loading(modulesIn: modules.directory)
            let compiledNames = Set(modules.compiled.map(\.name))
            var entries = modules.compiled.map { module in
                Entry(module: module, origin: .program, staleFile: Self.isStale(module, in: modules.directory))
            }
            for module in loaded.environment.modules
            where module.name != Frame.Module.frame.name && !compiledNames.contains(module.name) {
                entries.append(.init(module: module, origin: .file, staleFile: false))
            }
            self.entries = entries
            self.directory = modules.directory
            self.failures = loaded.failures.map { "\($0.file.lastPathComponent): \($0.error)" }
        }

        /// The module's file exists and does not match what the program
        /// would write; a missing file is not stale, just not installed.
        private static func isStale(_ module: Frame.Module, in directory: URL) -> Bool {
            let file = directory.appendingPathComponent("\(module.name).frame")
            guard let text = try? String(contentsOf: file, encoding: .utf8),
                  let expected = try? module.document().source
            else { return false }
            let body = text.hasPrefix("//")
                ? String(text.drop(while: { $0 != "\n" }).dropFirst())
                : text
            return body != expected
        }
    }

    /// The catalog for a tool call; without the application's modules,
    /// only the module files.
    static func catalog(in context: ToolContext) -> Catalog {
        let modules = (try? context.require(Modules.self)) ?? Modules(compiled: [])
        return Catalog(modules)
    }
}
