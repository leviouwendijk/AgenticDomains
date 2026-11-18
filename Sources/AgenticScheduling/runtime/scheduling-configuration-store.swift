import Agentic
import AgenticConfiguration
import Foundation
import Frame
import IO
import Readers
import Writers

public extension Scheduling.ConfigurationStore {
    /// The home's `domains/scheduling.frame`, archived into the home's
    /// `archive/`. The file is parsed again only when its text changes;
    /// `runtime` turns a configuration into a runtime, with the
    /// application's place resolver and travel estimator.
    init(
        home: AgentHome = AgentHomeLocator().resolveHome(),
        sources: [any CalendarSource],
        runtime: @escaping @Sendable (SchedulingConfiguration) -> Scheduling.Runtime
    ) {
        let file = home.layout.domainfile(SchedulingFrame.fileName)
        let cache = SchedulingLoadedState()
        self.init(file: file, archiveDirectory: home.layout.archivedir, sources: sources) {
            let text: String?
            do {
                let read = try TextFileReader(file).read(options: .init(missingFilePolicy: .returnEmpty))
                text = read.existed && !read.text.isEmpty ? read.text : nil
            } catch {
                return .invalid(file: file.path, message: error.localizedDescription)
            }
            return cache.state(for: text) {
                Scheduling.ConfigurationStore.load(text, file: file, runtime: runtime)
            }
        }
    }

    /// The configuration `text` of `file` as a state: loaded, missing (no
    /// text) or invalid.
    static func load(
        _ text: String?,
        file: URL,
        runtime: (SchedulingConfiguration) -> Scheduling.Runtime
    ) -> Scheduling.ConfigurationState {
        guard let text else {
            return .missing(expected: file.path)
        }
        do {
            return .loaded(runtime(try SchedulingConfiguration(source: text, filePath: file.path)))
        } catch {
            return .invalid(
                file: file.path,
                message: (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            )
        }
    }
}

/// The last loaded state, kept while the file's text is unchanged, so every
/// tool call sees a saved file without reparsing an unchanged one.
private final class SchedulingLoadedState: @unchecked Sendable {
    private let lock = NSLock()
    private var text: String??
    private var loaded: Scheduling.ConfigurationState?

    func state(
        for current: String?,
        load: () -> Scheduling.ConfigurationState
    ) -> Scheduling.ConfigurationState {
        lock.lock()
        defer { lock.unlock() }
        if let loaded, text == .some(current) {
            return loaded
        }
        let state = load()
        loaded = state
        text = .some(current)
        return state
    }
}

public extension Scheduling {
    /// Where the application keeps `scheduling.frame`, the calendar sources
    /// it reads, and how it loads the file. Inserted into `ToolServices` so
    /// scheduling can read and write its own configuration without access
    /// to the rest of the home, list calendars before any configuration
    /// exists, and pick up a saved file in the same session: `state()`
    /// loads the file on every call.
    struct ConfigurationStore: Sendable {
        public let file: URL
        /// Earlier files, kept when a save replaces one.
        public let archiveDirectory: URL
        public let sources: [any CalendarSource]
        private let load: @Sendable () -> ConfigurationState

        public init(
            file: URL,
            archiveDirectory: URL,
            sources: [any CalendarSource],
            load: @escaping @Sendable () -> ConfigurationState
        ) {
            self.file = file
            self.archiveDirectory = archiveDirectory
            self.sources = sources
            self.load = load
        }

        public func state() -> ConfigurationState {
            load()
        }

        /// The file's text; nil when there is none.
        public func text() throws -> String? {
            let read = try TextFileReader(file).read(options: .init(missingFilePolicy: .returnEmpty))
            return read.existed ? read.text : nil
        }

        /// Archives the current file, if any, then writes `text` in its
        /// place. Returns the archived copy.
        public func save(_ text: String, now: Date = Date()) throws -> URL? {
            var archived: URL?
            if let current = try self.text() {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd-HHmmss"
                let stem = "\(file.deletingPathExtension().lastPathComponent)-\(formatter.string(from: now))"
                // Saves within one second get -2, -3, ...
                var archive = archiveDirectory.appendingPathComponent("\(stem).frame")
                var count = 1
                while FileSystem.default.exists(archive) {
                    count += 1
                    archive = archiveDirectory.appendingPathComponent("\(stem)-\(count).frame")
                }
                try FileWriter(archive).write(current)
                archived = archive
            }
            try FileWriter(file).write(text, options: .overwriteWithoutBackup)
            return archived
        }
    }

    /// The calendar sources: from the loaded runtime, or from the store
    /// when no configuration loads.
    static func sources(in context: ToolContext) -> [any CalendarSource]? {
        if let runtime = try? runtime(in: context) {
            return runtime.sources
        }
        return (try? context.require(ConfigurationStore.self))?.sources
    }

    static func store(in context: ToolContext) throws -> ConfigurationStore {
        guard let store = try? context.require(ConfigurationStore.self) else {
            throw ConfigurationFailure.notProvided
        }
        return store
    }
}

/// Whether a `scheduling.frame` text holds: its syntax and schema, what
/// scheduling makes of it, and whether its calendars exist in the sources.
public struct SchedulingConfigurationCheck: Sendable, Hashable {
    /// Problems that make the file unusable: `line:column: message` where
    /// the schema locates them.
    public let problems: [String]
    /// Calendars the configuration names that no source shows.
    public let unknownCalendars: [String]
    /// What could not be checked, and other remarks.
    public let notes: [String]
    public let participants: [String]

    public var isValid: Bool { problems.isEmpty }

    public static func run(
        _ text: String,
        sources: [any CalendarSource]
    ) async -> Self {
        let document: Frame.Document
        do {
            document = try Frame.parse(text, filePath: SchedulingFrame.fileName)
        } catch {
            return .init(problems: [String(describing: error)], unknownCalendars: [], notes: [], participants: [])
        }
        let schemaProblems = Frame.problems(in: document, environment: SchedulingFrame.environment)
            .map { $0.located(in: text).description }
        guard schemaProblems.isEmpty else {
            return .init(problems: schemaProblems, unknownCalendars: [], notes: [], participants: [])
        }
        let configuration: SchedulingConfiguration
        do {
            configuration = try SchedulingConfiguration(source: text, filePath: SchedulingFrame.fileName)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            return .init(problems: [message], unknownCalendars: [], notes: [], participants: [])
        }

        var notes: [String] = []
        if configuration.participants.isEmpty {
            notes.append("No participants: requests can name nobody, and nobody's time is read.")
        }
        var declared: [CalendarPolicy] = []
        for policy in configuration.calendars + configuration.participants.flatMap(\.calendars)
        where !declared.contains(where: { $0.describesSameCalendar(as: policy) }) {
            declared.append(policy)
        }

        var visible: [CalendarReference] = []
        var everySourceRead = !sources.isEmpty
        for source in sources {
            do {
                visible += try await source.calendars()
            } catch {
                everySourceRead = false
                notes.append("Calendars of \(source.identifier) could not be read (\(error.localizedDescription)); its calendar names are unchecked.")
            }
        }
        if sources.isEmpty {
            notes.append("No calendar source to compare calendar names with; they are unchecked.")
        }
        let unknown = everySourceRead
            ? declared.filter { policy in !visible.contains(where: policy.matches) }.map(\.label)
            : []
        return .init(
            problems: [],
            unknownCalendars: unknown,
            notes: notes,
            participants: configuration.participants.map(\.identifier)
        )
    }
}
