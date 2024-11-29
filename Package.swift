// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZTronCarousel",
    platforms: [.iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ZTronCarousel",
            targets: ["ZTronCarousel"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SnapKit/SnapKit", branch: "develop"),
        .package(url: "https://github.com/NiccoloBargioni/ZTronObservation", branch: "bugfix/threadSafety"),
        .package(url: "https://github.com/NiccoloBargioni/ZTronCarouselCore", branch: "main"),
        .package(url: "https://github.com/NiccoloBargioni/ZTronSerializable", branch: "main"),
        .package(url: "https://github.com/Juanpe/SkeletonView", branch: "main"),
        .package(url: "https://github.com/mchoe/SwiftSVG", branch: "master")
    ],

    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ZTronCarousel",
            dependencies: [
                .product(name: "SnapKit", package: "SnapKit"),
                .product(name: "ZTronObservation", package: "ZTronObservation"),
                .product(name: "ZTronCarouselCore", package: "ZTronCarouselCore"),
                .product(name: "ZTronSerializable", package: "ZTronSerializable"),
                .product(name: "SkeletonView", package: "SkeletonView"),
                .product(name: "SwiftSVG", package: "SwiftSVG")
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=complete")
            ]
        ),
        .testTarget(
            name: "ZTronCarouselTests",
            dependencies: ["ZTronCarousel"]
        ),
    ]
)
