// swift-tools-version: 6.0

import Foundation
import PackageDescription

let enablesUpdates = ProcessInfo.processInfo.environment["BUNLET_ENABLE_SPARKLE"] == "1"
let sparkleTargets: [Target] = enablesUpdates ? [
    .binaryTarget(
        name: "Sparkle",
        url: "https://github.com/sparkle-project/Sparkle/releases/download/2.10.1/Sparkle-for-Swift-Package-Manager.zip",
        checksum: "4c2e48a3e50ebcc2c88a58a4c7264a1a99c3c31857ce754357afb9cdb323022a"
    )
] : []
let sparkleDependencies: [Target.Dependency] = enablesUpdates ? ["Sparkle"] : []
let sparkleLinkerSettings: [LinkerSetting] = enablesUpdates ? [
    .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
] : []

let package = Package(
    name: "NotchPet",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NotchPet", targets: ["NotchPet"]),
        .executable(name: "NotchPetHook", targets: ["NotchPetHook"]),
        .executable(name: "NotchPetStatusLine", targets: ["NotchPetStatusLine"]),
        .executable(name: "NotchPetActionHook", targets: ["NotchPetActionHook"])
    ],
    targets: [
        .target(name: "Pet", resources: [.process("Resources")]),
        .target(name: "EventBridge"),
        .target(name: "Integration", dependencies: ["EventBridge"]),
        .target(name: "Usage", dependencies: ["EventBridge"]),
        .target(name: "SessionState", dependencies: ["EventBridge"]),
        .target(name: "AgentActions", dependencies: ["EventBridge", "SessionState"]),
        .executableTarget(name: "NotchPet",
                          dependencies: ["Pet", "EventBridge", "SessionState", "Usage", "Integration", "AgentActions"] + sparkleDependencies,
                          resources: [.process("Resources")], linkerSettings: sparkleLinkerSettings),
        .executableTarget(name: "NotchPetHook", dependencies: ["EventBridge"]),
        .executableTarget(name: "NotchPetStatusLine", dependencies: ["Usage"]),
        .executableTarget(name: "NotchPetActionHook", dependencies: ["AgentActions"]),
        .testTarget(name: "EventBridgeTests", dependencies: ["EventBridge"]),
        .testTarget(name: "PetTests", dependencies: ["Pet"]),
        .testTarget(name: "NotchPetTests", dependencies: ["NotchPet", "EventBridge", "SessionState", "Integration", "AgentActions"]),
        .testTarget(name: "UsageTests", dependencies: ["Usage", "EventBridge"]),
        .testTarget(name: "IntegrationTests", dependencies: ["Integration", "SessionState", "EventBridge"]),
        .testTarget(name: "SessionStateTests", dependencies: ["SessionState", "EventBridge", "Integration"])
    ] + sparkleTargets
)
