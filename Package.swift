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
            name: "AgenticSwift",
            targets: ["AgenticSwift"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Agentic.git", branch: "master"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.1"),

        // .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Writers.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Readers.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Path.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/FileTypes.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Selection.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Concatenation.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Interfaces.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Tokens.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Matching.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Ranking.git", branch: "master"),
        // .package(url: "https://github.com/leviouwendijk/Fuzzy.git", branch: "master"),

        // .package(url: "https://github.com/leviouwendijk/Executable.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "AgenticSwift",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(
                    name: "SwiftParser",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftSyntax",
                    package: "swift-syntax"
                ),

                // .product(name: "Primitives", package: "Primitives"),
                // .product(name: "Writers", package: "Writers"),
                // .product(name: "Readers", package: "Readers"),
                // .product(name: "FileTypes", package: "FileTypes"),
                .product(name: "Path", package: "Path"),
                // .product(name: "PathParsing", package: "Path"),
                // .product(name: "Selection", package: "Selection"),
                // .product(name: "SelectionParsing", package: "Selection"),
                .product(name: "Position", package: "Position"),
                // .product(name: "Concatenation", package: "Concatenation"),
                // .product(name: "Interfaces", package: "Interfaces"),
                // .product(name: "Tokens", package: "Tokens"),
                // .product(name: "Matching", package: "Matching"),
                // .product(name: "Ranking", package: "Ranking"),
                // .product(name: "Fuzzy", package: "Fuzzy"),

                // .product(name: "Executable", package: "Executable"),
            ]
        ),
        // .testTarget(
        //     name: "AgenticDomainsTests",
        //     dependencies: ["AgenticDomains"]
        // ),
    ]
)
