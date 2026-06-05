// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Gifrog",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Gifrog", targets: ["Gifrog"])
    ],
    targets: [
        .executableTarget(
            name: "Gifrog",
            path: "Sources/Gifrog",
            exclude: [
                "Resources/GifrogIcon.svg",
                "Resources/GifrogIconTemplate.svg"
            ],
            resources: [
                .copy("Resources/GifrogIcon.png"),
                .copy("Resources/GifrogIconTemplate.png")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        )
    ]
)
