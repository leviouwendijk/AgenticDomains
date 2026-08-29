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
        .executable(
            name: "domtest",
            targets: ["AgenticDomainsTestFlows"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Agentic.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/AgenticExecution.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/AgenticWorkspace.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/AgenticIO.git", branch: "master"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.1"),

        .package(url: "https://github.com/leviouwendijk/Path.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Parsers.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Accounting.git", branch: "master"),

        // .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Writers.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Readers.git", branch: "master"),
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
        .package(url: "https://github.com/leviouwendijk/Schema.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/TestFlows.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "AgenticDomains",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticExecution", package: "AgenticExecution"),
                "AgenticSwift",
                "AgenticWeb",
                "AgenticGit",
            ]
        ),

        .target(
            name: "AgenticSwift",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticExecution", package: "AgenticExecution"),
                .product(name: "AgenticWorkspace", package: "AgenticWorkspace"),
                .product(name: "AgenticIO", package: "AgenticIO"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
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
            ]
        ),
        .target(
            name: "AgenticWeb",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticExecution", package: "AgenticExecution"),
                .product(name: "AgenticWorkspace", package: "AgenticWorkspace"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Parsers", package: "Parsers"),
            ]
        ),

        .target(
            name: "AgenticGit",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticExecution", package: "AgenticExecution"),
                .product(name: "AgenticWorkspace", package: "AgenticWorkspace"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Interfaces", package: "Interfaces"),
            ]
        ),

        // .target(
        //     name: "AgenticAccounting",
        //     dependencies: [
        //         .product(name: "Agentic", package: "Agentic"),
        //         .product(name: "Accounting", package: "Accounting"),
        //     ]
        // ),

        .executableTarget(
            name: "AgenticDomainsTestFlows",
            dependencies: [
                "AgenticSwift",
                "AgenticGit",
                "AgenticWeb",
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticExecution", package: "AgenticExecution"),
                .product(name: "AgenticWorkspace", package: "AgenticWorkspace"),
                .product(name: "Executable", package: "Executable"),
                .product(name: "Interfaces", package: "Interfaces"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "TestFlows", package: "TestFlows"),
            ]
        ),
    ]
)
