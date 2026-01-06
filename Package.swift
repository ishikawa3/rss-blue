// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RSSBlueDependencies",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [],
    dependencies: [
        .package(url: "https://github.com/nmdias/FeedKit.git", from: "9.1.2")
    ],
    targets: []
)
