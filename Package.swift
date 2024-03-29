// swift-tools-version:5.3

import PackageDescription

struct ProjectSettings {
    static let marketingVersion: String = "3.3.1"
}

let package = Package(
    name: "SRGIdentity",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v12),
        .tvOS(.v12)
    ],
    products: [
        .library(
            name: "SRGIdentity",
            targets: ["SRGIdentity"]
        )
    ],
    dependencies: [
        .package(name: "FXReachability", url: "https://github.com/SRGSSR/FXReachability.git", .exact("1.3.2-srg6")),
        .package(name: "Mantle", url: "https://github.com/Mantle/Mantle.git", .upToNextMinor(from: "2.2.0")),
        .package(name: "SRGAppearance", url: "https://github.com/SRGSSR/srgappearance-apple.git", .upToNextMinor(from: "5.2.0")),
        .package(name: "SRGNetwork", url: "https://github.com/SRGSSR/srgnetwork-apple.git", .upToNextMinor(from: "3.1.0")),
        .package(name: "UICKeyChainStore", url: "https://github.com/kishikawakatsumi/UICKeyChainStore.git", .upToNextMinor(from: "2.2.1"))
    ],
    targets: [
        .target(
            name: "SRGIdentity",
            dependencies: ["FXReachability", "Mantle", "SRGAppearance", "SRGNetwork", "UICKeyChainStore"],
            resources: [
                .process("Resources")
            ],
            cSettings: [
                .define("MARKETING_VERSION", to: "\"\(ProjectSettings.marketingVersion)\""),
                .define("NS_BLOCK_ASSERTIONS", to: "1", .when(configuration: .release))
            ]
        )
    ]
)
