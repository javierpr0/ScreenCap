// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenCap",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ScreenCap",
            targets: ["ScreenCap"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.3.0"),
        .package(url: "https://github.com/getsentry/sentry-cocoa.git", from: "8.53.2")
    ],
    targets: [
        .executableTarget(
            name: "ScreenCap",
            dependencies: ["KeyboardShortcuts", .product(name: "Sentry", package: "sentry-cocoa")],
            path: ".",
            sources: [
                "ScreenCapApp.swift",
                "ScreenshotManager.swift",
                "SettingsView.swift",
                "FloatingPreviewWindow.swift",
                "ImageDragView.swift",
                "KeyboardShortcutNames.swift"
            ],
            resources: [
                .process("ScreenCap.entitlements")
            ]
        )
    ]
)