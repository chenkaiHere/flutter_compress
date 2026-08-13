// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_compress",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "flutter-compress", targets: ["flutter_compress"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_compress",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // App Store requires third-party SDKs to ship a signed privacy
                // manifest — keep this in step with the podspec's resource_bundles
                // so both build systems package it.
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
