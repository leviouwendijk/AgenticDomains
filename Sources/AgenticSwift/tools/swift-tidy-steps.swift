import Executable
import Foundation
import Primitives

/// The clean and wipe steps around a build or test run (`sbm --clean-before --wipe`), reported
/// into a bounded buffer the tool returns instead of the host's standard output.
struct SwiftTidySteps: Sendable {
    let cleanBefore: Bool
    let wipeBefore: Bool
    let clean: Bool
    let wipe: Bool
    let buffer = TextBuffer(limit: 16_384)

    init(
        cleanBefore: Bool?,
        wipeBefore: Bool?,
        clean: Bool?,
        wipe: Bool?
    ) {
        self.cleanBefore = cleanBefore == true
        self.wipeBefore = wipeBefore == true
        self.clean = clean == true
        self.wipe = wipe == true
    }

    init(_ input: SwiftTestRunInput) {
        self.init(cleanBefore: input.cleanBefore, wipeBefore: input.wipeBefore, clean: input.clean, wipe: input.wipe)
    }

    var sink: TextSink {
        buffer.sink
    }

    var sideEffects: [String] {
        var effects: [String] = []
        if wipeBefore {
            effects.append("Deletes .build and .index-build first (keep list applies).")
        } else if cleanBefore {
            effects.append("Runs swift package clean first.")
        }
        if wipe {
            effects.append("Deletes .build and .index-build after a successful run (keep list applies).")
        } else {
            if clean {
                effects.append("Runs swift package clean after a successful run.")
            }
            effects.append("Wipes caches that exceed a package.frame .wipe.above after a successful run.")
        }
        return effects
    }

    func before(_ packages: [URL]) async throws {
        try await SwiftBuildSteps.tidy(packages, clean: cleanBefore, wipe: wipeBefore, output: sink)
    }

    func after(_ packages: [URL]) async throws {
        try await SwiftBuildSteps.tidyAfter(packages, clean: clean, wipe: wipe, output: sink)
    }

    /// The steps' report, marked when its start was dropped; nil when nothing was reported.
    var report: String? {
        buffer.isEmpty ? nil : Self.report(buffer)
    }

    static func report(_ buffer: TextBuffer) -> String {
        let dropped = buffer.dropped
        return (dropped > 0 ? "… (\(dropped) earlier characters dropped)\n" : "") + buffer.text()
    }
}
