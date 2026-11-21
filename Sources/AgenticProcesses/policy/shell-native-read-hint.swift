import Agentic
import AgenticIO

public extension Shell {
    /// Points a read-shaped command line at the native tools that do the same
    /// work, usually without review and in one batched call.
    ///
    /// Advisory only: a wrong guess costs a useless or missing note. It never
    /// feeds `risk` or `mayChangeSource`; those wait for real command analysis.
    enum NativeReadHint {
        public enum Use:
            Sendable,
            Hashable,
            CaseIterable
        {
            case read
            case search
            case list
        }

        /// The note for `command`, or nil unless every stage only reads files.
        public static func hint(
            for command: String
        ) -> String? {
            let uses = uses(of: command)

            guard !uses.isEmpty else {
                return nil
            }

            let tools = Use.allCases
                .filter(uses.contains)
                .map(\.tools)
                .joined(separator: "; ")

            return "This command only reads files. Native tools do this without a shell, usually without review, and batch: \(tools)."
        }

        /// What the command line uses files for; empty when any stage may do
        /// more than read, or when nothing is read at all.
        public static func uses(
            of command: String
        ) -> Set<Use> {
            let line = command
                .replacingOccurrences(of: "2>&1", with: " ")
                .replacingOccurrences(of: "2>/dev/null", with: " ")

            guard let stages = stages(of: line) else {
                return []
            }

            var uses: Set<Use> = []

            for stage in stages {
                switch Self.stage(stage.words, piped: stage.piped) {
                case .use(let use):
                    uses.insert(use)
                case .neutral:
                    continue
                case .other:
                    return []
                }
            }

            return uses
        }
    }
}

public extension Shell.NativeReadHint.Use {
    /// The native tools for this use, by identifier.
    var identifiers: [ToolIdentifier] {
        switch self {
        case .read:
            return [SystemIO.Tools.ReadFiles.identifier]
        case .search:
            return [SystemIO.Tools.SearchSources.identifier]
        case .list:
            return [
                SystemIO.Tools.ScanFilepaths.identifier,
                SystemIO.Tools.SearchFilepaths.identifier,
            ]
        }
    }

    var tools: String {
        let names = identifiers
            .map { "`\($0.rawValue)`" }
            .joined(separator: " or ")

        switch self {
        case .read:
            return "\(names) (several files or line windows in one call with `reads`)"
        case .search:
            return "\(names) (text or pattern, with matching lines)"
        case .list:
            return "\(names) (paths and names)"
        }
    }
}

private extension Shell.NativeReadHint {
    enum Stage {
        case use(Use)
        case neutral
        case other
    }

    static let readers: Set<String> = [
        "cat", "head", "tail", "nl", "wc",
    ]

    static let searchers: Set<String> = [
        "rg", "grep", "egrep", "fgrep",
    ]

    static let listers: Set<String> = [
        "ls", "find", "tree",
    ]

    /// Separators, layout and pure text filters: they neither read files nor
    /// change anything on their own.
    static let neutral: Set<String> = [
        "cd", "echo", "printf", "uniq", "cut", "tr",
    ]

    static let findActions: Set<String> = [
        "-delete", "-exec", "-execdir", "-ok", "-okdir",
        "-fprint", "-fprint0", "-fprintf", "-fls",
    ]

    /// One command between separators; `piped` when it reads the previous
    /// stage's output through `|`.
    struct Words {
        let words: [String]
        let piped: Bool
    }

    /// A piped reader or searcher filters the previous stage's output
    /// (`| head -20`, `| grep -v .build`); it reads no file of its own.
    static func stage(
        _ words: [String],
        piped: Bool
    ) -> Stage {
        guard let program = words.first else {
            return .neutral
        }
        let arguments = words.dropFirst()

        if readers.contains(program) {
            return piped ? .neutral : .use(.read)
        }
        if searchers.contains(program) {
            return piped ? .neutral : .use(.search)
        }
        if neutral.contains(program) {
            return .neutral
        }

        switch program {
        case "sed":
            let quiet = arguments.contains("-n")
            let inPlace = arguments.contains { $0.hasPrefix("-i") || $0.hasPrefix("--in-place") }
            guard quiet && !inPlace else {
                return .other
            }
            return piped ? .neutral : .use(.read)
        case "sort":
            return arguments.contains { $0.hasPrefix("-o") || $0.hasPrefix("--output") }
                ? .other
                : .neutral
        case _ where listers.contains(program):
            return arguments.contains(where: findActions.contains)
                ? .other
                : .use(.list)
        default:
            return .other
        }
    }

    /// Splits a command line into stages of words at unquoted `|`, `&`, `;`
    /// and newlines. Nil when it redirects, substitutes or reads a heredoc.
    static func stages(
        of line: String
    ) -> [Words]? {
        var stages: [Words] = []
        var words: [String] = []
        var word = ""
        var quote: Character?
        var escaped = false
        var piped = false

        func endWord() {
            if !word.isEmpty {
                words.append(word)
                word = ""
            }
        }

        func endStage() {
            endWord()
            if !words.isEmpty {
                stages.append(.init(words: words, piped: piped))
                words = []
            }
        }

        var previous: Character?

        for character in line {
            defer {
                previous = character
            }

            if escaped {
                word.append(character)
                escaped = false
                continue
            }

            if let open = quote {
                if character == open {
                    quote = nil
                } else if open == "\"" && (character == "`" || (character == "(" && previous == "$")) {
                    return nil
                } else if open == "\"" && character == "\\" {
                    escaped = true
                } else {
                    word.append(character)
                }
                continue
            }

            switch character {
            case "\\":
                escaped = true
            case "'", "\"":
                quote = character
            case "|":
                endStage()
                // `||` is a list, not a pipe.
                piped = previous != "|"
            case "&", ";", "\n":
                endStage()
                piped = false
            case "<", ">", "`":
                return nil
            case "(" where previous == "$":
                return nil
            case _ where character.isWhitespace:
                endWord()
            default:
                word.append(character)
            }
        }

        guard quote == nil else {
            return nil
        }

        endStage()
        return stages
    }
}
