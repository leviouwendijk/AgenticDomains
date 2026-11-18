import Agentic
import Foundation
import Frame
import Macros
import Schema

public extension FrameLang.Tools {
    @Tool("frame_check")
    struct Check {
        @JSONSchema
        public struct Input: HashableSource {
            /// The whole file. Read an existing file with read_file first.
            public let text: String
            /// Its name, for messages only.
            public let file: String?

            public init(text: String, file: String? = nil) {
                self.text = text
                self.file = file
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            /// No problems: it parses, every import resolves, every binding
            /// fits its type.
            public let valid: Bool
            /// `line:column: message`, every one found.
            public let problems: [String]
            /// The modules it imports, and where each came from.
            public let imports: [String]
        }

        public static let purpose =
            "Check a Frame (.frame) file: syntax, imports and every binding against its type, reporting every problem with its line. Run it on any Frame file you write, until it is valid. Checks the schema only: a domain may still reject what the schema allows."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let catalog = FrameLang.catalog(in: context)
            let document: Frame.Document
            do {
                document = try Frame.parse(input.text, filePath: input.file)
            } catch {
                return .init(valid: false, problems: [String(describing: error)], imports: [])
            }
            let problems = Frame.problems(in: document, environment: catalog.environment)
                .map { $0.located(in: input.text).description }
            let imports = document.imports.map { item in
                guard let entry = catalog.entry(named: item.module) else {
                    return item.module == Frame.Module.frame.name ? "\(item.module) (module files)" : "\(item.module) (unknown)"
                }
                return "\(item.module) (\(entry.origin.rawValue))"
            }
            return .init(valid: problems.isEmpty, problems: problems, imports: imports)
        }
    }
}
