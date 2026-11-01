// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Prokachka",
    platforms: [.macOS(.v14)],
    targets: [
        // Формула опыта и журнал событий. Без UI, чтобы проверяться тест-векторами из spec/.
        .target(
            name: "ProkachkaCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Prokachka",
            dependencies: ["ProkachkaCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ProkachkaCoreTests",
            dependencies: ["ProkachkaCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
