// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Oathkeeper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Oathkeeper", targets: ["Oathkeeper"])
    ],
    targets: [
        .executableTarget(
            name: "Oathkeeper",
            path: "Sources"
        )
    ]
)
