import Agentic
import Foundation
import Frame
import Macros
import Schema

public extension FrameLang.Tools {
    @Tool("frame_modules")
    struct ListModules {
        @JSONSchema
        public struct Input: HashableSource {
            public init() {}
        }

        @JSONSchema
        public struct Module: HashableResult {
            /// What `import <name>;` names.
            public let name: String
            /// `program`: compiled in, exactly what is decoded. `file`: only
            /// a module file.
            public let origin: FrameLang.Origin
            /// The types the module makes nameable.
            public let types: [String]
            /// Its module file differs from the program; `agentic
            /// frame-module` rewrites it.
            public let stale_file: Bool
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let modules: [Module]
            /// Where module files are read from.
            public let directory: String
            /// Module files that could not be read.
            public let failures: [String]
        }

        public static let purpose =
            "The Frame modules a .frame file may import (`import Name;`), with their types. Use before writing or checking a Frame configuration file, then frame_schema for a module's fields."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_: Input, in context: ToolContext) async throws -> Output {
            let catalog = FrameLang.catalog(in: context)
            return .init(
                modules: catalog.entries.map { entry in
                    .init(
                        name: entry.module.name,
                        origin: entry.origin,
                        types: entry.module.types.map(\.name),
                        stale_file: entry.staleFile
                    )
                },
                directory: catalog.directory.path,
                failures: catalog.failures
            )
        }
    }
}
