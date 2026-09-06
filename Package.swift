// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TravelCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "TravelCore", targets: ["TravelCore"])],
    targets: [
        .target(name: "TravelCore", path: "Core"),
        .target(name: "AttachmentSupport", dependencies: ["TravelCore"], path: "App/Services"),
        .testTarget(name: "TravelCoreTests", dependencies: ["TravelCore"], path: "Tests/TravelCoreTests"),
        .testTarget(name: "AttachmentSupportTests", dependencies: ["AttachmentSupport", "TravelCore"], path: "Tests/AttachmentSupportTests")
    ]
)
