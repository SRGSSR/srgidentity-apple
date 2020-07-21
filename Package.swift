// swift-tools-version:5.3

import PackageDescription

struct ProjectSettings {
    static let marketingVersion: String = "2.0.5"
}

let package = Package(
    name: "SRGIdentity",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v9),
        .tvOS(.v12)
    ],
    products: [
        .library(
            name: "SRGIdentity",
            targets: ["SRGIdentity"]
        )
    ],
    dependencies: [
        .package(name: "FXReachability", url: "https://github.com/SRGSSR/FXReachability.git", .branch("feature/spm-support")),
        .package(name: "Mantle", url: "https://github.com/SRGSSR/Mantle.git", .branch("swift-package-manager-support")),
        .package(name: "SRGAppearance", url: "https://github.com/SRGSSR/srgappearance-apple.git", .branch("feature/spm-support")),
        .package(name: "SRGNetwork", url: "https://github.com/SRGSSR/srgnetwork-apple.git", .branch("feature/spm-support")),
        .package(name: "UICKeyChainStore", url: "https://github.com/kishikawakatsumi/UICKeyChainStore.git", .exact("2.2.0"))
    ],
    targets: [
        .target(
            name: "SRGIdentity",
            dependencies: ["FXReachability", "Mantle", "SRGAppearance", "SRGNetwork", "UICKeyChainStore"],
            resources: [
                .process("Resources")
            ],
            cSettings: [
                .define("MARKETING_VERSION", to: "\"\(ProjectSettings.marketingVersion)\"")
            ]
        )
    ]
)
