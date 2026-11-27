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

        // mail over the accounts in domains/mail.frame
        .library(
            name: "AgenticMail",
            targets: ["AgenticMail"]
        ),

        // task-neutral agents and operating guidance; applications fork GeneralPurpose
        .library(
            name: "AgenticGeneral",
            targets: ["AgenticGeneral"]
        ),

        // the Frame configuration language: modules, schemas, checking
        // language-agnostic development agents (orchestration, scouting, review)
        .library(
            name: "AgenticDevelopment",
            targets: ["AgenticDevelopment"]
        ),

        // Loa: the model writes one program instead of a series of tool calls
        .library(
            name: "AgenticLoa",
            targets: ["AgenticLoa"]
        ),

    ],
    dependencies: [
        .package(url: "https://github.com/swift-agentic/Agentic.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Surface.git", branch: "master"),
        .package(url: "https://github.com/swift-agentic/AgenticIO.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Workspace.git", branch: "master"),

        .package(url: "https://github.com/swift-tooling/SwiftSemantics.git", branch: "master"),
        .package(url: "https://github.com/swift-tooling/Documentation.git", branch: "master"),

        .package(url: "https://github.com/swift-lco/Path.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Position.git", branch: "master"),
        .package(url: "https://github.com/swift-langs/Parsers.git", branch: "master"),
        // .package(url: "https://github.com/depaix-labs/Accounting.git", branch: "master"),

        // .package(url: "https://github.com/swift-lco/Primitives.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Writers.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Readers.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/IO.git", branch: "master"),
        // .package(url: "https://github.com/swift-lco/FileTypes.git", branch: "master"),
        // .package(url: "https://github.com/swift-lco/Selection.git", branch: "master"),
        // .package(url: "https://github.com/swift-lco/Concatenation.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Interfaces.git", branch: "master"),
        // .package(url: "https://github.com/swift-langs/Tokens.git", branch: "master"),
        // .package(url: "https://github.com/swift-lco/Matching.git", branch: "master"),
        // .package(url: "https://github.com/swift-lco/Ranking.git", branch: "master"),
        // .package(url: "https://github.com/swift-lco/Fuzzy.git", branch: "master"),
        .package(url: "https://github.com/swift-tooling/Executable.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Version.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Primitives.git", branch: "master"),
        .package(url: "https://github.com/loa-lang/loa.git", branch: "master"),
        .package(url: "https://github.com/swift-sdk/Apple.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Schema.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Macros.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Errors.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Reporting.git", branch: "master"),
        .package(url: "https://github.com/swift-dsl/DSL.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Search.git", branch: "master"),
        .package(url: "https://github.com/swift-sdk/UniFi.git", branch: "master"),
        .package(url: "https://github.com/swift-sdk/Mail.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Difference.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Processes.git", branch: "master"),
        .package(url: "https://github.com/lco-langs/Frame.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Sensitivity.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "AgenticLoa",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Loa", package: "loa"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
                .product(name: "Surface", package: "Surface"),
            ]
        ),

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
                "AgenticGeneral",
                "AgenticScheduling",
            ]
        ),

        .target(
            name: "AgenticScheduling",
            dependencies: [
                .product(name: "Errors", package: "Errors"),
                .product(name: "AgenticFrame", package: "Agentic"),
                .product(name: "AgenticContext", package: "Agentic"),
                .product(name: "AgenticConfiguration", package: "Agentic"),
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

        .target(
            name: "AgenticMail",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticContext", package: "Agentic"),
                .product(name: "AgenticStandard", package: "Agentic"),
                .product(name: "AgenticConfiguration", package: "Agentic"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
                .product(name: "IO", package: "IO"),
                .product(name: "Mail", package: "Mail"),
                .product(name: "MailConnection", package: "Mail"),
                .product(name: "SMTP", package: "Mail"),
                .product(name: "IMAP", package: "Mail"),
                .product(name: "MailFrame", package: "Mail"),
                .product(name: "MailIndex", package: "Mail"),
                .product(name: "Errors", package: "Errors"),
            ]
        ),

        .target(
            name: "AgenticGeneral",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticStandard", package: "Agentic"),
                .product(name: "AgenticHarness", package: "Agentic"),
                .product(name: "AgenticMath", package: "Agentic"),
                .product(name: "AgenticAssertions", package: "Agentic"),
                .product(name: "AgenticTasks", package: "Agentic"),
                .product(name: "AgenticIO", package: "AgenticIO"),
                .product(name: "AgenticSessions", package: "Agentic"),
                "AgenticGit",
                "AgenticProcesses",

                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
            ],
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
                "AgenticGeneral",
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
            name: "AgenticAppleServices",
            dependencies: [
                .product(name: "Surface", package: "Surface"),
                "AgenticScheduling",
                .product(name: "Apple", package: "Apple"),
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticConfiguration", package: "Agentic"),
                .product(name: "Workspace", package: "Workspace"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Readers", package: "Readers"),
                .product(name: "Writers", package: "Writers"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
                .product(name: "Interfaces", package: "Interfaces"),
            ]
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
                .product(name: "Sensitivity", package: "Sensitivity"),
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
                .product(name: "AgenticIO", package: "AgenticIO"),
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
