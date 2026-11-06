// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NotchPet",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NotchPet", targets: ["NotchPet"]),
        .executable(name: "NotchPetHook", targets: ["NotchPetHook"]),
        .executable(name: "NotchPetStatusLine", targets: ["NotchPetStatusLine"])
    ],
    targets: [
        .target(name: "Pet", resources: [.process("Resources")]),
        .target(name: "EventBridge"),
        .target(name: "Integration", dependencies: ["EventBridge"]),
        .target(name: "Usage", dependencies: ["EventBridge"]),
        .target(name: "SessionState", dependencies: ["EventBridge"]),
        .executableTarget(name: "NotchPet", dependencies: ["Pet", "EventBridge", "SessionState", "Usage", "Integration"],
                          resources: [.process("Resources")]),
        .executableTarget(name: "NotchPetHook", dependencies: ["EventBridge"]),
        .executableTarget(name: "NotchPetStatusLine", dependencies: ["Usage"]),
        .testTarget(name: "EventBridgeTests", dependencies: ["EventBridge"]),
        .testTarget(name: "PetTests", dependencies: ["Pet"]),
        .testTarget(name: "NotchPetTests", dependencies: ["NotchPet", "EventBridge", "SessionState", "Integration"]),
        .testTarget(name: "UsageTests", dependencies: ["Usage", "EventBridge"]),
        .testTarget(name: "IntegrationTests", dependencies: ["Integration", "SessionState", "EventBridge"]),
        .testTarget(name: "SessionStateTests", dependencies: ["SessionState", "EventBridge", "Integration"])
    ]
)
