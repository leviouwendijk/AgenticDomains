import Agentic
import AgenticIO
import Foundation

public extension Shell.NativeReadHint {
    /// A native call that does what part of a command line did.
    struct Equivalent:
        Sendable,
        Hashable
    {
        public let tool: ToolIdentifier
        /// The call's input as compact JSON: built from the tool's own input
        /// type, with every field at its default left out.
        public let input: String

        public init(
            tool: ToolIdentifier,
            input: String
        ) {
            self.tool = tool
            self.input = input
        }

        public var call: String {
            "\(tool.rawValue) \(input)"
        }
    }

    /// Native calls that do what `command` does: one `read` call for
    /// all reads, one call per search or listing. Empty unless every read,
    /// search and listing in the command translates faithfully.
    static func equivalents(
        of command: String
    ) -> [Equivalent] {
        guard !uses(of: command).isEmpty,
              let stages = stages(of: normalized(command))
        else {
            return []
        }

        var translation = Translation()

        guard translation.add(stages) else {
            return []
        }

        return translation.equivalents
    }
}

private typealias ReadTool = SystemIO.Tools.Read
private typealias SearchTool = SystemIO.Tools.Search
private typealias FindTool = SystemIO.Tools.Find

/// Translates pipelines one by one. Any part without a faithful native form
/// makes `add` return false.
private struct Translation {
    var directory: String?
    var reads: [ReadTool.Window] = []
    var numbered = false
    var searches: [SearchTool.Input] = []
    var listings: [FindTool.Input] = []

    mutating func add(
        _ stages: [Shell.NativeReadHint.Words]
    ) -> Bool {
        var start = 0

        while start < stages.count {
            var end = start + 1
            while end < stages.count && stages[end].piped {
                end += 1
            }

            let followers = stages[(start + 1)..<end].map(\.words)

            guard add(stages[start].words, followers: followers) else {
                return false
            }
            start = end
        }

        return reads.count <= ReadTool.maximumReads
    }

    var equivalents: [Shell.NativeReadHint.Equivalent] {
        var equivalents: [Shell.NativeReadHint.Equivalent] = []

        if let read = readEquivalent {
            equivalents.append(read)
        }
        equivalents += searches.compactMap {
            Self.equivalent(
                SearchTool.identifier,
                $0,
                defaults: SearchTool.Input()
            )
        }
        equivalents += listings.compactMap {
            Self.equivalent(
                FindTool.identifier,
                $0,
                defaults: FindTool.Input()
            )
        }

        return equivalents
    }
}

// MARK: - Pipelines

private extension Translation {
    mutating func add(
        _ words: [String],
        followers: [[String]]
    ) -> Bool {
        guard let program = words.first else {
            return true
        }
        let arguments = Array(words.dropFirst())

        switch program {
        case "cd":
            return followers.isEmpty && changeDirectory(arguments)
        case "echo", "printf":
            return followers.isEmpty
        case "cat", "head", "nl", "sed":
            return read(program, arguments, followers: followers)
        case "rg", "grep", "egrep", "fgrep":
            return search(program, arguments)
        case "ls", "find", "tree":
            return list(program, arguments, followers: followers)
        default:
            return false
        }
    }

    mutating func changeDirectory(
        _ arguments: [String]
    ) -> Bool {
        guard arguments.count == 1,
              let path = path(arguments[0])
        else {
            return false
        }

        directory = path.isEmpty ? nil : path
        return true
    }

    /// A workspace-relative path for `raw`, joined to the current `cd`;
    /// "" for the root. Nil for anything read could not take as is.
    func path(
        _ raw: String
    ) -> String? {
        let unsafe: Set<Character> = ["*", "?", "[", "]", "{", "}", "$", "~"]

        guard !raw.isEmpty,
              !raw.hasPrefix("/"),
              !raw.hasPrefix("-"),
              !raw.contains(where: unsafe.contains),
              !raw.split(separator: "/").contains("..")
        else {
            return nil
        }

        var relative = raw
        while relative.hasPrefix("./") {
            relative.removeFirst(2)
        }
        while relative.hasSuffix("/") {
            relative.removeLast()
        }
        if relative == "." {
            relative = ""
        }

        guard let directory else {
            return relative
        }
        return relative.isEmpty
            ? directory
            : "\(directory)/\(relative)"
    }
}

// MARK: - Reads

private extension Translation {
    /// How a single following stage cuts a read.
    enum Cut {
        case none
        case first(Int)
        case lines(Int, Int?)
    }

    mutating func read(
        _ program: String,
        _ arguments: [String],
        followers: [[String]]
    ) -> Bool {
        var files: [String] = []
        var own = Cut.none

        switch program {
        case "cat":
            for argument in arguments {
                if argument == "-n" {
                    numbered = true
                } else if argument.hasPrefix("-") {
                    return false
                } else {
                    files.append(argument)
                }
            }
        case "nl":
            for argument in arguments {
                if argument == "-ba" {
                    numbered = true
                } else if argument.hasPrefix("-") {
                    return false
                } else {
                    files.append(argument)
                }
            }
            numbered = true
        case "head":
            guard let parsed = Self.head(arguments) else {
                return false
            }
            own = .first(parsed.count)
            files = parsed.files
        case "sed":
            guard let parsed = Self.sed(arguments) else {
                return false
            }
            own = .lines(parsed.start, parsed.end)
            files = parsed.files
        default:
            return false
        }

        guard !files.isEmpty,
              let cut = cut(own, followers: followers, files: files.count)
        else {
            return false
        }

        for file in files {
            guard let path = path(file), !path.isEmpty else {
                return false
            }
            reads.append(Self.window(path, cut))
        }
        return true
    }

    /// The program's own cut, or one following `head` / `sed -n` on a
    /// single file; nil for any other following stage.
    func cut(
        _ own: Cut,
        followers: [[String]],
        files: Int
    ) -> Cut? {
        guard let follower = followers.first else {
            return own
        }
        guard followers.count == 1,
              files == 1,
              case .none = own,
              let program = follower.first
        else {
            return nil
        }
        let arguments = Array(follower.dropFirst())

        switch program {
        case "head":
            guard let parsed = Self.head(arguments), parsed.files.isEmpty else {
                return nil
            }
            return .first(parsed.count)
        case "sed":
            guard let parsed = Self.sed(arguments), parsed.files.isEmpty else {
                return nil
            }
            return .lines(parsed.start, parsed.end)
        default:
            return nil
        }
    }

    static func window(
        _ path: String,
        _ cut: Cut
    ) -> ReadTool.Window {
        switch cut {
        case .none:
            return .init(path: path)
        case .first(let count):
            return .init(path: path, maxLines: count)
        case .lines(let start, let end):
            return .init(path: path, startLine: start, endLine: end)
        }
    }

    /// `head`, `head -N`, `head -n N`, `head -nN`, then files.
    static func head(
        _ arguments: [String]
    ) -> (count: Int, files: [String])? {
        var count = 10
        var files: [String] = []
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]

            if argument == "-n" {
                index += 1
                guard index < arguments.count, let value = Int(arguments[index]) else {
                    return nil
                }
                count = value
            } else if argument.hasPrefix("-n"), let value = Int(argument.dropFirst(2)) {
                count = value
            } else if argument.hasPrefix("-"), let value = Int(argument.dropFirst()) {
                count = value
            } else if argument.hasPrefix("-") {
                return nil
            } else {
                files.append(argument)
            }
            index += 1
        }

        return count > 0 ? (count, files) : nil
    }

    /// `sed -n 'Ap'`, `'A,Bp'` or `'A,$p'`, then files.
    static func sed(
        _ arguments: [String]
    ) -> (start: Int, end: Int?, files: [String])? {
        guard arguments.contains("-n") else {
            return nil
        }
        let rest = arguments.filter { $0 != "-n" }

        guard let script = rest.first,
              script.hasSuffix("p"),
              !rest.dropFirst().contains(where: { $0.hasPrefix("-") })
        else {
            return nil
        }

        let range = script.dropLast().split(separator: ",", omittingEmptySubsequences: false)

        switch range.count {
        case 1:
            guard let line = Int(range[0]), line > 0 else {
                return nil
            }
            return (line, line, Array(rest.dropFirst()))
        case 2:
            guard let start = Int(range[0]), start > 0 else {
                return nil
            }
            if range[1] == "$" {
                return (start, nil, Array(rest.dropFirst()))
            }
            guard let end = Int(range[1]), end >= start else {
                return nil
            }
            return (start, end, Array(rest.dropFirst()))
        default:
            return nil
        }
    }

    var readEquivalent: Shell.NativeReadHint.Equivalent? {
        guard !reads.isEmpty else {
            return nil
        }

        let input: ReadTool.Input
        if reads.count == 1, let window = reads.first {
            input = .init(
                path: window.path,
                startLine: window.startLine,
                endLine: window.endLine,
                maxLines: window.maxLines,
                includeLineNumbers: numbered
            )
        } else {
            input = .init(
                reads: reads,
                includeLineNumbers: numbered
            )
        }

        guard var object = Self.compact(input, defaults: ReadTool.Input()),
              let window = Self.object(ReadTool.Window(path: ""))
        else {
            return nil
        }
        // Windows inside `reads` drop their defaults too.
        for (key, value) in object {
            guard let elements = value as? [[String: Any]] else {
                continue
            }
            object[key] = elements.map {
                Self.compact($0, defaults: window)
            }
        }

        return Self.equivalent(ReadTool.identifier, object)
    }
}

// MARK: - Searches

private extension Translation {
    mutating func search(
        _ program: String,
        _ arguments: [String]
    ) -> Bool {
        var expression: String?
        var literal = program == "fgrep"
        var extended = program != "grep"
        var ignoreCase = false
        var context = 0
        var globs: [String] = []
        var paths: [String] = []
        var index = 0

        func value(
            after letters: Substring,
            at position: String.Index
        ) -> String? {
            let rest = letters[letters.index(after: position)...]
            if !rest.isEmpty {
                return String(rest)
            }
            index += 1
            return index < arguments.count ? arguments[index] : nil
        }

        while index < arguments.count {
            let argument = arguments[index]

            if argument.hasPrefix("--") {
                switch argument {
                case "--ignore-case":
                    ignoreCase = true
                case "--fixed-strings":
                    literal = true
                case "--extended-regexp":
                    extended = true
                case "--recursive", "--line-number", "--no-heading", "--with-filename", "--color=never", "--no-messages":
                    break
                case _ where argument.hasPrefix("--include="):
                    globs.append(String(argument.dropFirst("--include=".count)))
                case _ where argument.hasPrefix("--glob="):
                    globs.append(String(argument.dropFirst("--glob=".count)))
                case _ where argument.hasPrefix("--context="):
                    guard let lines = Int(argument.dropFirst("--context=".count)) else {
                        return false
                    }
                    context = max(context, lines)
                default:
                    return false
                }
            } else if argument.hasPrefix("-"), argument.count > 1 {
                let letters = argument.dropFirst()
                var position = letters.startIndex

                letters: while position < letters.endIndex {
                    switch letters[position] {
                    case "n", "r", "R", "H", "s", "I":
                        break
                    case "i":
                        ignoreCase = true
                    case "F":
                        literal = true
                    case "E":
                        extended = true
                    case "A", "B", "C":
                        guard let lines = value(after: letters, at: position).flatMap(Int.init) else {
                            return false
                        }
                        context = max(context, lines)
                        break letters
                    case "e":
                        guard expression == nil, let given = value(after: letters, at: position) else {
                            return false
                        }
                        expression = given
                        break letters
                    case "g":
                        guard let glob = value(after: letters, at: position) else {
                            return false
                        }
                        globs.append(glob)
                        break letters
                    case "t":
                        guard program == "rg", let type = value(after: letters, at: position) else {
                            return false
                        }
                        globs.append("*.\(type)")
                        break letters
                    default:
                        return false
                    }
                    position = letters.index(after: position)
                }
            } else if expression == nil {
                expression = argument
            } else {
                paths.append(argument)
            }
            index += 1
        }

        guard let expression, !expression.isEmpty,
              let term = Self.term(expression, literal: literal, extended: extended),
              let includes = includes(paths, globs: globs)
        else {
            return false
        }

        searches.append(
            .init(
                includes: includes,
                query: term.query,
                pattern: term.pattern,
                contextLines: context,
                caseSensitive: !ignoreCase
            )
        )
        return true
    }

    /// Literal text as `query`, a regular expression as `pattern`. Basic
    /// grep syntax translates only its escaped alternation and groups.
    static func term(
        _ expression: String,
        literal: Bool,
        extended: Bool
    ) -> (query: String?, pattern: String?)? {
        if literal {
            return (expression, nil)
        }

        var translated = expression
        if !extended {
            let escaped = expression
                .replacingOccurrences(of: "\\|", with: "")
                .replacingOccurrences(of: "\\(", with: "")
                .replacingOccurrences(of: "\\)", with: "")
            let special: Set<Character> = ["|", "+", "?", "(", ")", "{", "}"]
            guard !escaped.contains(where: special.contains) else {
                return nil
            }
            translated = expression
                .replacingOccurrences(of: "\\|", with: "|")
                .replacingOccurrences(of: "\\(", with: "(")
                .replacingOccurrences(of: "\\)", with: ")")
        }

        let metacharacters: Set<Character> = [
            ".", "*", "+", "?", "|", "(", ")", "[", "]", "{", "}", "^", "$", "\\",
        ]
        return translated.contains(where: metacharacters.contains)
            ? (nil, translated)
            : (translated, nil)
    }

    /// Include expressions for the searched paths and globs. A path that
    /// looks like a file is taken as is, anything else as a directory.
    func includes(
        _ paths: [String],
        globs: [String]
    ) -> [String]? {
        var bases: [String] = []

        for raw in paths.isEmpty ? ["."] : paths {
            guard let base = path(raw) else {
                return nil
            }
            bases.append(base)
        }

        guard !globs.contains(where: { $0.hasPrefix("!") || $0.contains("..") }) else {
            return nil
        }

        var includes: [String] = []
        for base in bases {
            let prefix = base.isEmpty ? "" : "\(base)/"

            if globs.isEmpty {
                includes.append(
                    Self.looksLikeFile(base) ? base : "\(prefix)**"
                )
            } else {
                for glob in globs {
                    includes.append(
                        glob.contains("/") ? "\(prefix)\(glob)" : "\(prefix)**/\(glob)"
                    )
                }
            }
        }
        return includes
    }

    static func looksLikeFile(
        _ path: String
    ) -> Bool {
        guard let last = path.split(separator: "/").last else {
            return false
        }
        return !last.hasPrefix(".") && last.contains(".")
    }
}

// MARK: - Listings

private extension Translation {
    mutating func list(
        _ program: String,
        _ arguments: [String],
        followers: [[String]]
    ) -> Bool {
        var maximum: Int?

        if let follower = followers.first {
            guard followers.count == 1,
                  follower.first == "head",
                  let parsed = Self.head(Array(follower.dropFirst())),
                  parsed.files.isEmpty
            else {
                return false
            }
            maximum = parsed.count
        }

        let listing: FindTool.Input?
        switch program {
        case "ls":
            listing = ls(arguments, maximum: maximum)
        case "find":
            listing = find(arguments, maximum: maximum)
        case "tree":
            listing = tree(arguments, maximum: maximum)
        default:
            listing = nil
        }

        guard let listing else {
            return false
        }
        listings.append(listing)
        return true
    }

    func ls(
        _ arguments: [String],
        maximum: Int?
    ) -> FindTool.Input? {
        var hidden = false
        var recursive = false
        var paths: [String] = []

        for argument in arguments {
            if argument.hasPrefix("-") {
                for letter in argument.dropFirst() {
                    switch letter {
                    case "a", "A":
                        hidden = true
                    case "R":
                        recursive = true
                    case "l", "h", "1", "F":
                        break
                    default:
                        return nil
                    }
                }
            } else {
                paths.append(argument)
            }
        }

        guard paths.count <= 1, let base = path(paths.first ?? ".") else {
            return nil
        }
        return .init(
            path: base.isEmpty ? nil : base,
            recursive: recursive ? true : nil,
            includeHidden: hidden,
            maxEntries: maximum
        )
    }

    func find(
        _ arguments: [String],
        maximum: Int?
    ) -> FindTool.Input? {
        var rest = arguments[...]
        var root = "."

        if let first = rest.first, !first.hasPrefix("-") {
            root = first
            rest = rest.dropFirst()
        }

        var files = true
        var directories = true
        var depth: Int?

        while let predicate = rest.first {
            rest = rest.dropFirst()

            switch predicate {
            case "-type":
                guard let kind = rest.first else {
                    return nil
                }
                rest = rest.dropFirst()
                switch kind {
                case "f":
                    directories = false
                case "d":
                    files = false
                default:
                    return nil
                }
            case "-maxdepth":
                guard let value = rest.first.flatMap({ Int($0) }) else {
                    return nil
                }
                rest = rest.dropFirst()
                depth = value
            case "-print":
                break
            default:
                return nil
            }
        }

        guard let base = path(root) else {
            return nil
        }
        return .init(
            path: base.isEmpty ? nil : base,
            recursive: true,
            maxdepth: depth,
            includeHidden: true,
            includeFiles: files,
            includeDirectories: directories,
            maxEntries: maximum
        )
    }

    func tree(
        _ arguments: [String],
        maximum: Int?
    ) -> FindTool.Input? {
        guard arguments.count <= 1,
              !(arguments.first?.hasPrefix("-") ?? false),
              let base = path(arguments.first ?? ".")
        else {
            return nil
        }
        return .init(
            path: base.isEmpty ? nil : base,
            recursive: true,
            maxEntries: maximum
        )
    }
}

// MARK: - Encoding

private extension Translation {
    /// `value` as a JSON object without the fields equal to `defaults`.
    static func compact<Value: Encodable>(
        _ value: Value,
        defaults: Value
    ) -> [String: Any]? {
        guard let encoded = object(value),
              let base = object(defaults)
        else {
            return nil
        }
        return compact(encoded, defaults: base)
    }

    static func compact(
        _ object: [String: Any],
        defaults: [String: Any]
    ) -> [String: Any] {
        object.filter { key, value in
            guard let original = defaults[key] else {
                return true
            }
            return !(original as AnyObject).isEqual(value)
        }
    }

    static func object(
        _ value: some Encodable
    ) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(value) else {
            return nil
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func equivalent<Input: Encodable>(
        _ tool: ToolIdentifier,
        _ input: Input,
        defaults: Input
    ) -> Shell.NativeReadHint.Equivalent? {
        compact(input, defaults: defaults).flatMap {
            equivalent(tool, $0)
        }
    }

    static func equivalent(
        _ tool: ToolIdentifier,
        _ object: [String: Any]
    ) -> Shell.NativeReadHint.Equivalent? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        ) else {
            return nil
        }
        return .init(
            tool: tool,
            input: String(decoding: data, as: UTF8.self)
        )
    }
}
