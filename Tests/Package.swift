// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AgenticDomainsTests",
    platforms: [
        .macOS(.v13)
    ],
    products: [

        .executable(
            name: "t_agentic_scheduling",
            targets: ["AgenticSchedulingTests"]
        ),

        .executable(
            name: "t_agentic_mail",
            targets: ["AgenticMailTests"]
        ),

        .executable(
            name: "t_agentic_processes",
            targets: ["AgenticProcessesTests"]
        ),

        .executable(
            name: "t_agentic_loa",
            targets: ["AgenticLoaTests"]
        ),

    ],
    dependencies: [
        .package(url: "https://github.com/swift-agentic/Agentic.git", branch: "master"),
        .package(url: "https://github.com/swift-agentic/AgenticIO.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Errors.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Reporting.git", branch: "master"),
        .package(url: "https://github.com/swift-sdk/Mail.git", branch: "master"),
        .package(url: "https://github.com/swift-tooling/Testing.git", branch: "master"),
        .package(url: "https://github.com/lco-langs/Frame.git", branch: "master"),
        .package(url: "https://github.com/loa-lang/loa.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Surface.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Primitives.git", branch: "master"),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "AgenticLoaTests",
            dependencies: [
                .product(name: "AgenticLoa", package: "AgenticDomains"),
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Loa", package: "loa"),
                .product(name: "Surface", package: "Surface"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Testing", package: "Testing"),
            ]
        ),




        .executableTarget(
            name: "AgenticSchedulingTests",
            dependencies: [
                .product(name: "AgenticScheduling", package: "AgenticDomains"),
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticConfiguration", package: "Agentic"),
                .product(name: "AgenticStandard", package: "Agentic"),
                .product(name: "Frame", package: "Frame"),
                .product(name: "Testing", package: "Testing"),
                .product(name: "Reporting", package: "Reporting"),
            ]
        ),

        .executableTarget(
            name: "AgenticMailTests",
            dependencies: [
                .product(name: "AgenticMail", package: "AgenticDomains"),
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Reporting", package: "Reporting"),
                .product(name: "Mail", package: "Mail"),
                .product(name: "IMAP", package: "Mail"),
                .product(name: "MailConnection", package: "Mail"),
                .product(name: "MailFrame", package: "Mail"),
                .product(name: "MailIndex", package: "Mail"),
                .product(name: "Errors", package: "Errors"),
                .product(name: "Testing", package: "Testing"),
            ]
        ),

        .executableTarget(
            name: "AgenticProcessesTests",
            dependencies: [
                .product(name: "AgenticProcesses", package: "AgenticDomains"),
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticIO", package: "AgenticIO"),
                .product(name: "Testing", package: "Testing"),
            ]
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
