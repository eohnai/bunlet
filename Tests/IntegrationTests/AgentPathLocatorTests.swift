import EventBridge
import Foundation
import Testing
@testable import Integration

/// Fictional home and install layout; no real files are read.
struct AgentPathLocatorTests {
    private let home = URL(fileURLWithPath: "/fictional/home")

    private func lookup(_ agent: Agent, policy: AgentPathLocator.ExecutablePolicy = .health, path: String? = nil,
                        executables: Set<String>, nvm: [String] = []) -> AgentPathLocator.ExecutableLookup {
        AgentPathLocator.executable(agent: agent, policy: policy, searchPath: path, homeDirectory: home,
                                    isExecutable: { executables.contains($0) },
                                    listDirectory: { $0 == "/fictional/home/.nvm/versions/node" ? nvm : [] })
    }

    @Test(arguments: [AgentPathLocator.ExecutablePolicy.health, .usage])
    func findsNativeInstallOutsideMinimalPath(policy: AgentPathLocator.ExecutablePolicy) {
        let claude = "/fictional/home/.local/bin/claude"
        #expect(lookup(.claude, policy: policy, path: "/usr/bin:/bin", executables: [claude])
                == .found(URL(fileURLWithPath: claude)))
    }

    @Test func findsNewestNvmInstall() {
        let old = "/fictional/home/.nvm/versions/node/v9.11.2/bin/codex"
        let new = "/fictional/home/.nvm/versions/node/v24.18.0/bin/codex"
        #expect(lookup(.codex, executables: [old, new], nvm: ["v9.11.2", "v24.18.0", "v20.1.0"])
                == .found(URL(fileURLWithPath: new)))
    }

    @Test func pathStillWinsOverFallbacks() {
        let onPath = "/fictional/tools/codex"
        let fallback = "/fictional/home/.local/bin/codex"
        #expect(lookup(.codex, path: "/fictional/tools", executables: [onPath, fallback])
                == .found(URL(fileURLWithPath: onPath)))
    }

    @Test func missingEverywhereIsNotFound() {
        #expect(lookup(.claude, executables: [], nvm: ["v24.18.0"]) == .notFound)
    }

    @Test func nvmEntriesAreBoundedAndOrdered() {
        let names = (0..<40).map { "v\($0).0.0" } + ["not-a-version", "v1/../../escape"]
        let directories = AgentPathLocator.userInstallDirectories(home: home, listDirectory: { _ in names })
        let nvm = directories.filter { $0.contains(".nvm") }
        #expect(nvm.count == 32)
        #expect(nvm.first == "/fictional/home/.nvm/versions/node/v39.0.0/bin")
        #expect(!directories.contains { $0.contains("escape") || $0.contains("not-a-version") })
    }
}
