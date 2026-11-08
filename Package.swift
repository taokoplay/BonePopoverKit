// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BonePopoverKit",
    platforms: [.iOS(.v15)],
    products: [.library(name: "BonePopoverKit", targets: ["BonePopoverKit"])],
    targets: [
        .target(name: "BonePopoverKit"),
        .testTarget(name: "BonePopoverKitTests", dependencies: ["BonePopoverKit"])
    ]
)
