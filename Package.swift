// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "hazakura-wallpaper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HazakuraWallpaper", targets: ["SakuraSky"]),
        .executable(name: "SakuraSkyMemorySmoke", targets: ["SakuraSkyMemorySmoke"]),
        .executable(name: "SakuraSkyPreview", targets: ["SakuraSkyPreview"]),
        .library(name: "SakuraSkyCore", targets: ["SakuraSkyCore"]),
        .library(name: "SakuraSkyRenderer", targets: ["SakuraSkyRenderer"])
    ],
    targets: [
        .target(name: "SakuraSkyCore"),
        .target(
            name: "SakuraSkyRenderer",
            dependencies: ["SakuraSkyCore"]
        ),
        .executableTarget(
            name: "SakuraSky",
            dependencies: ["SakuraSkyCore", "SakuraSkyRenderer"]
        ),
        .executableTarget(
            name: "SakuraSkyPreview",
            dependencies: ["SakuraSkyCore", "SakuraSkyRenderer"]
        ),
        .executableTarget(
            name: "SakuraSkyMemorySmoke",
            dependencies: ["SakuraSkyCore", "SakuraSkyRenderer"]
        ),
        .testTarget(
            name: "SakuraSkyCoreTests",
            dependencies: ["SakuraSkyCore"]
        ),
        .testTarget(
            name: "SakuraSkyRendererTests",
            dependencies: ["SakuraSkyCore", "SakuraSkyRenderer"]
        )
    ]
)
