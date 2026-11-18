// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AgenticDomains",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AgenticDomains",
            targets: ["AgenticDomains"]
        ),

        .library(
            name: "AgenticSwift",
            targets: ["AgenticSwift"]
        ),

        .library(
            name: "AgenticWeb",
            targets: ["AgenticWeb"]
        ),

        .library(
            name: "AgenticGit",
            targets: ["AgenticGit"]
        ),

        .library(
            name: "AgenticAppleServices",
            targets: ["AgenticAppleServices"]
        ),

        .library(
            name: "AgenticBusiness",
            targets: ["AgenticBusiness"]
        ),

        .library(
            name: "AgenticUniFi",
            targets: ["AgenticUniFi"]
        ),

        .library(
            name: "AgenticProcesses",
            targets: ["AgenticProcesses"]
        ),

        // provider-neutral scheduling: busy time, conflicts, slots, travel
        .library(
            name: "AgenticScheduling",
            targets: ["AgenticScheduling"]
        ),

        .executable(
            name: "t_agentic_scheduling",
            targets: ["AgenticSchedulingTests"]
        ),

        // mail over the accounts in domains/mail.frame
        .library(
            name: "AgenticMail",
            targets: ["AgenticMail"]
        ),

        .executable(
            name: "t_agentic_mail",
            targets: ["AgenticMailTests"]
        ),

        // the Frame configuration language: modules, schemas, checking
        // language-agnostic development agents (orchestration, scouting, review)
        .library(
            name: "AgenticDevelopment",
            targets: ["AgenticDevelopment"]
        ),

    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Agentic.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/AgenticIO.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Workspace.git", branch: "master"),

        .package(url: "https://github.com/leviouwendijk/SwiftSemantics.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Documentation.git", branch: "master"),

        .package(url: "https://github.com/leviouwendijk/Path.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Parsers.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Accounting.git", branch: "master"),

        // .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Writers.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Readers.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/IO.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/FileTypes.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Selection.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Concatenation.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Interfaces.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Tokens.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Matching.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Ranking.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Fuzzy.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Executable.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Version.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Milieu.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Schema.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Macros.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Errors.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Reporting.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/DSL.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Search.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/UniFi.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Mail.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Difference.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Processes.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Testing.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Frame.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "AgenticDomains",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                "AgenticSwift",
                "AgenticWeb",
                "AgenticGit",
                "AgenticAppleServices",
                "AgenticBusiness",
                "AgenticUniFi",
                "AgenticProcesses",
                "AgenticDevelopment",
                "AgenticScheduling",
            ]
        ),

        .target(
            name: "AgenticScheduling",
            dependencies: [
                .product(name: "AgenticFrame", package: "Agentic"),
                .product(name: "AgenticContext", package: "Agentic"),
                .product(name: "IO", package: "IO"),
                .product(name: "Readers", package: "Readers"),
                .product(name: "Writers", package: "Writers"),
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticStandard", package: "Agentic"),
                .product(name: "AgenticMath", package: "Agentic"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
                .product(name: "Frame", package: "Frame"),
                .product(name: "Reporting", package: "Reporting"),
                .product(name: "DSL", package: "DSL"),
                .product(name: "Search", package: "Search"),
            ]
        ),



        .executableTarget(
            name: "AgenticSchedulingTests",
            dependencies: [
                "AgenticScheduling",
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticStandard", package: "Agentic"),
                .product(name: "Frame", package: "Frame"),
                .product(name: "Testing", package: "Testing"),
                .product(name: "Reporting", package: "Reporting"),
            ],
            path: "Testing/AgenticSchedulingTests"
        ),

        .target(
            name: "AgenticMail",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticStandard", package: "Agentic"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
                .product(name: "Mail", package: "Mail"),
                .product(name: "MailConnection", package: "Mail"),
                .product(name: "SMTP", package: "Mail"),
                .product(name: "IMAP", package: "Mail"),
                .product(name: "MailFrame", package: "Mail"),
            ]
        ),

        .executableTarget(
            name: "AgenticMailTests",
            dependencies: [
                "AgenticMail",
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Mail", package: "Mail"),
                .product(name: "IMAP", package: "Mail"),
                .product(name: "MailConnection", package: "Mail"),
                .product(name: "MailFrame", package: "Mail"),
                .product(name: "Testing", package: "Testing"),
            ],
            path: "Testing/AgenticMailTests"
        ),

        .target(
            name: "AgenticDevelopment",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticStandard", package: "Agentic"),
                .product(name: "AgenticHarness", package: "Agentic"),
                .product(name: "AgenticMath", package: "Agentic"),
                .product(name: "AgenticAssertions", package: "Agentic"),
                .product(name: "AgenticTasks", package: "Agentic"),
                .product(name: "AgenticIO", package: "AgenticIO"),
                .product(name: "AgenticSessions", package: "Agentic"),
                "AgenticSwift",
                "AgenticGit",
                "AgenticProcesses",

                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
            ],
        ),

        .target(
            name: "AgenticSwift",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticStandard", package: "Agentic"),
                .product(name: "AgenticMath", package: "Agentic"),
                .product(name: "AgenticAssertions", package: "Agentic"),
                .product(name: "AgenticTasks", package: "Agentic"),
                .product(name: "AgenticIO", package: "AgenticIO"),
                "AgenticGit",
                .product(name: "Workspace", package: "Workspace"),

                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
                .product(name: "SwiftSemantics", package: "SwiftSemantics"),
                .product(name: "SwiftRefactoring", package: "SwiftSemantics"),
                .product(name: "SwiftRefactoringWriters", package: "SwiftSemantics"),
                .product(name: "Writers", package: "Writers"),
                .product(name: "Documentation", package: "Documentation"),
                .product(name: "Path", package: "Path"),
                .product(name: "Position", package: "Position"),

                // .product(name: "Primitives", package: "Primitives"),
                // .product(name: "Writers", package: "Writers"),
                // .product(name: "Readers", package: "Readers"),
                // .product(name: "FileTypes", package: "FileTypes"),
                // .product(name: "PathParsing", package: "Path"),
                // .product(name: "Selection", package: "Selection"),
                // .product(name: "SelectionParsing", package: "Selection"),
                // .product(name: "Concatenation", package: "Concatenation"),
                // .product(name: "Interfaces", package: "Interfaces"),
                // .product(name: "Tokens", package: "Tokens"),
                // .product(name: "Matching", package: "Matching"),
                // .product(name: "Ranking", package: "Ranking"),
                // .product(name: "Fuzzy", package: "Fuzzy"),

                .product(name: "Executable", package: "Executable"),
                .product(name: "Version", package: "Version"),
            ],
        ),
        .target(
            name: "AgenticWeb",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Workspace", package: "Workspace"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
                .product(name: "Parsers", package: "Parsers"),
            ],
        ),

        .target(
            name: "AgenticGit",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Workspace", package: "Workspace"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
                .product(name: "Interfaces", package: "Interfaces"),
            ],
        ),

        .target(
            name: "AppleMusicBridge",
            path: "Sources/AppleMusicBridge",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("ScriptingBridge")]
        ),

        .target(
            name: "AgenticAppleServices",
            dependencies: [
                "AppleMusicBridge",
                "AgenticScheduling",
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Workspace", package: "Workspace"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Milieu", package: "Milieu"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
                .product(name: "Interfaces", package: "Interfaces"),
            ],
            linkerSettings: [.linkedFramework("iTunesLibrary")]
        ),

        .target(
            name: "AgenticBusiness",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
            ],
        ),

        .target(
            name: "AgenticUniFi",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticStandard", package: "Agentic"),
                .product(name: "AgenticAssertions", package: "Agentic"),
                .product(name: "AgenticMath", package: "Agentic"),

                .product(name: "UniFiPlanning", package: "UniFi"),
                .product(name: "Errors", package: "Errors"),
                .product(name: "Difference", package: "Difference"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
            ],
        ),

        .target(
            name: "AgenticProcesses",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Workspace", package: "Workspace"),
                .product(name: "Processes", package: "Processes"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
            ],
        ),

        // .target(
        //     name: "AgenticAccounting",
        //     dependencies: [
        //         .product(name: "Agentic", package: "Agentic"),
        //         .product(name: "Accounting", package: "Accounting"),
        //     ]
        // ),

    ]
)

for target in package.targets {
    switch target.type {
    case .regular, .executable, .test, .macro:
        var settings = target.swiftSettings ?? []

        settings.append(
            .treatAllWarnings(as: .error)
        )

        settings.append(
            .unsafeFlags(
                [
                    "-continue-building-after-errors"
                ]
            )
        )

        target.swiftSettings = settings

    case .plugin, .system, .binary:
        break

    @unknown default:
        break
    }
}
