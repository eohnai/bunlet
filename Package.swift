// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NotchPet",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NotchPet", targets: ["NotchPet"]),
        .executable(name: "NotchPetHook", targets: ["NotchPetHook"])
    ],
    targets: [
        .target(name: "Pet", resources: [.process("Resources")]),
        .target(name: "EventBridge"),
        .target(name: "SessionState", dependencies: ["EventBridge"]),
        .executableTarget(name: "NotchPet", dependencies: ["Pet", "EventBridge", "SessionState"],
                          resources: [.process("Resources")]),
        .executableTarget(name: "NotchPetHook", dependencies: ["EventBridge"]),
        .testTarget(name: "EventBridgeTests", dependencies: ["EventBridge"]),
        .testTarget(name: "PetTests", dependencies: ["Pet"]),
        .testTarget(name: "NotchPetTests", dependencies: ["NotchPet"]),
        .testTarget(name: "SessionStateTests", dependencies: ["SessionState", "EventBridge"])
    ]
)
