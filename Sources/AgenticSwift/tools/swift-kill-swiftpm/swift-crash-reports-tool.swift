import Agentic
import Workspace
import Executable
import Foundation
import Primitives
import Schema
import Macros

public struct SwiftCrashReportsTool: Tool {
    @JSONSchema
    public struct Input:
        Sendable,
        Codable,
        Hashable
    {
        /// Maximum number of most-recent reports to return. Defaults to 5 and is clamped to 1...20.
        public let limit: Int?

        /// Case-insensitive report file-name prefix. Defaults to "swift", which covers swift-package, swift-build, swift-frontend, and swift-driver.
        public let processPrefix: String?

        /// Maximum crashed-thread frames returned per report. Defaults to 30 and is clamped to 0...80.
        public let frameLimit: Int?

        public init(
            limit: Int? = nil,
            processPrefix: String? = nil,
            frameLimit: Int? = nil
        ) {
            self.limit = limit
            self.processPrefix = processPrefix
            self.frameLimit = frameLimit
        }
    }

    @JSONSchema
    public struct Output:
        Sendable,
        Codable,
        Hashable
    {
        @JSONSchema
        public struct Report:
            Sendable,
            Codable,
            Hashable
        {
            public let file: String
            public let process: String
            public let timestamp: String?
            public let exceptionType: String?
            public let signal: String?
            public let message: String?
            public let frameCount: Int
            public let recursionDepth: Int?
            public let frames: [String]

            public init(
                file: String,
                process: String,
                timestamp: String?,
                exceptionType: String?,
                signal: String?,
                message: String?,
                frameCount: Int,
                recursionDepth: Int?,
                frames: [String]
            ) {
                self.file = file
                self.process = process
                self.timestamp = timestamp
                self.exceptionType = exceptionType
                self.signal = signal
                self.message = message
                self.frameCount = frameCount
                self.recursionDepth = recursionDepth
                self.frames = frames
            }
        }

        public let directory: String
        public let reports: [Report]

        public init(
            directory: String,
            reports: [Report]
        ) {
            self.directory = directory
            self.reports = reports
        }
    }

    public static let identifier: ToolIdentifier = "swift_crash_reports"
    public static let description =
        "Read the most recent macOS crash reports for Swift toolchain processes (swift-package, swift-build, swift-frontend) through Executable.SwiftCrashReports: signal, exception message, recursion depth, and leading crashed-thread frames. Use after a Swift tool exits on a signal such as exit 138 (SIGBUS) or 139 (SIGSEGV)."
    public static let risk: ActionRisk = .observe

    public static let definition = ToolDefinition(
        identifier: identifier,
        purpose: description,
        risk: risk
    )

    public var identifier: ToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}

    public func preflight(
        _ input: Input,
        in context: ToolContext
    ) async throws -> ToolPreflight {
        _ = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )

        return ToolPreflight(
            tool: Self.definition.identifier,
            risk: risk,
            summary: "Read recent Swift toolchain crash reports.",
            access: .init(
                targets: [
                    SwiftCrashReports.defaultDirectory.path
                ]
            ),
            sideEffects: [],
            policyChecks: [
                "workspace_required",
                "typed_crash_report_reading",
                "swift_toolchain_reports_only",
            ],
            warnings: [
                "The macOS crash report directory is outside the attached Agentic workspace."
            ]
        )
    }

    public func call(
        _ input: Input,
        in context: ToolContext
    ) async throws -> Output {
        _ = try AgenticSwiftToolSupport.requireWorkspace(
            context.workspace,
            toolName: Self.definition.identifier.rawValue
        )

        let directory = SwiftCrashReports.defaultDirectory
        let limit = min(
            20,
            max(1, input.limit ?? 5)
        )
        let frameLimit = min(
            80,
            max(0, input.frameLimit ?? 30)
        )
        let requestedPrefix = (input.processPrefix ?? "")
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        let prefix = requestedPrefix.isEmpty
            ? "swift"
            : requestedPrefix

        let files = try SwiftCrashReports.list(
            in: directory,
            processPrefix: prefix,
            limit: limit
        )

        var reports: [Output.Report] = []

        for file in files {
            do {
                let report = try SwiftCrashReports.read(
                    at: file,
                    frameLimit: frameLimit
                )

                reports.append(
                    .init(
                        file: file.lastPathComponent,
                        process: report.process,
                        timestamp: report.timestamp,
                        exceptionType: report.exceptionType,
                        signal: report.signal,
                        message: report.message,
                        frameCount: report.frameCount,
                        recursionDepth: report.recursionDepth,
                        frames: report.frames.map(\.rendered)
                    )
                )
            } catch {
                reports.append(
                    .init(
                        file: file.lastPathComponent,
                        process: "<unreadable>",
                        timestamp: nil,
                        exceptionType: nil,
                        signal: nil,
                        message: error.localizedDescription,
                        frameCount: 0,
                        recursionDepth: nil,
                        frames: []
                    )
                )
            }
        }

        return Output(
            directory: directory.path,
            reports: reports
        )
    }

    public func process(
        _ output: Output,
        input _: Input
    ) -> ToolCall.ResultProjection? {
        var facts: [ToolCall.ResultProjection.Fact] = [
            .init(label: "reports", value: "\(output.reports.count)")
        ]

        if let latest = output.reports.first {
            facts.append(.init(label: "latest", value: latest.file))

            if let signal = latest.signal {
                facts.append(.init(label: "signal", value: signal))
            }

            if let depth = latest.recursionDepth {
                facts.append(.init(label: "recursion depth", value: "\(depth)"))
            }
        }

        return .init(
            status: "passed",
            summary: output.reports.isEmpty
                ? "No matching Swift crash reports were found."
                : "Read \(output.reports.count) Swift crash report(s).",
            facts: facts
        )
    }
}
