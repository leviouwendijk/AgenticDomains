import Agentic
import Foundation
import Frame
import Macros
import Schema

public extension FrameLang.Tools {
    @Tool("frame_schema")
    struct ModuleSchema {
        @JSONSchema
        public struct Input: HashableSource {
            /// A module name from frame_modules, such as `Agentic` or
            /// `Scheduling`.
            public let module: String

            public init(module: String) {
                self.module = module
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let module: String
            public let origin: FrameLang.Origin
            /// The module's types as Frame source: every field, whether it
            /// is required, its allowed members, and what it means.
            public let source: String
        }

        public static let purpose =
            "A Frame module's types as Frame source: fields, required ones, allowed members and their meaning. Read it before writing a file that imports the module."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let catalog = FrameLang.catalog(in: context)
            guard let entry = catalog.entry(named: input.module) else {
                throw FrameLang.ToolFailure.unknownModule(
                    input.module,
                    known: catalog.entries.map(\.module.name)
                )
            }
            return .init(
                module: entry.module.name,
                origin: entry.origin,
                source: try entry.module.document().source
            )
        }
    }
}

public extension FrameLang {
    enum ToolFailure: Error, LocalizedError {
        case unknownModule(String, known: [String])

        public var errorDescription: String? {
            switch self {
            case .unknownModule(let name, let known):
                return "no Frame module '\(name)'; there is: \(known.joined(separator: ", "))"
            }
        }
    }
}
