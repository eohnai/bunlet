import Foundation
import Integration
import Testing

struct AgentPathLocatorTests {
    private let home = URL(fileURLWithPath: "/fictional/home")
    private let policies: [AgentPathLocator.ExecutablePolicy] = [.health, .usage]

    private func extras(_ agent: IntegrationAgent) -> [String] {
        ["/fictional/home/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"]
            .map { $0 + "/" + agent.rawValue }
    }

    private func candidates(_ agent: IntegrationAgent, policy: AgentPathLocator.ExecutablePolicy,
                            path: String?) -> [String] {
        var visited: [String] = []
        let result = AgentPathLocator.executable(
            agent: agent, policy: policy, searchPath: path, homeDirectory: home,
            isExecutable: { visited.append($0); return false })
        #expect(result == .notFound)
        return visited
    }

    @Test func missingPathUsesPolicyFallbacks() {
        for agent in IntegrationAgent.allCases {
            #expect(candidates(agent, policy: .health, path: nil) ==
                ["/usr/bin", "/bin", "/usr/sbin", "/sbin"].map { $0 + "/" + agent.rawValue })
            #expect(candidates(agent, policy: .usage, path: nil) ==
                ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin", "/bin"]
                    .map { $0 + "/" + agent.rawValue } + extras(agent))
        }
    }

    @Test func emptyPathPreservesPolicyBehavior() {
        for agent in IntegrationAgent.allCases {
            #expect(candidates(agent, policy: .health, path: "").isEmpty)
            #expect(candidates(agent, policy: .usage, path: "") == extras(agent))
        }
    }

    @Test func absoluteCandidatesKeepOrder() {
        for agent in IntegrationAgent.allCases {
            for policy in policies {
                let first = "/fictional/first/" + agent.rawValue
                let second = "/fictional/second/" + agent.rawValue
                var visited: [String] = []
                let result = AgentPathLocator.executable(
                    agent: agent, policy: policy,
                    searchPath: "relative:/fictional/first::./relative:/fictional/second:/fictional/third",
                    homeDirectory: home,
                    isExecutable: { visited.append($0); return $0 == second })
                #expect(result == .found(URL(fileURLWithPath: second)))
                #expect(visited == [first, second])
            }
        }
    }

    @Test func componentLimitPreservesEmptyHandling() {
        for agent in IntegrationAgent.allCases {
            let emptyPrefix = String(repeating: ":", count: 63) + "/fictional/accepted:/fictional/ignored"
            #expect(candidates(agent, policy: .health, path: emptyPrefix) ==
                ["/fictional/accepted/" + agent.rawValue])
            #expect(candidates(agent, policy: .usage, path: emptyPrefix) ==
                ["/fictional/accepted/" + agent.rawValue, "/fictional/ignored/" + agent.rawValue] + extras(agent))

            let relativePrefix = Array(repeating: "relative", count: 64).joined(separator: ":") + ":/fictional/ignored"
            #expect(candidates(agent, policy: .health, path: relativePrefix).isEmpty)
            #expect(candidates(agent, policy: .usage, path: relativePrefix) == extras(agent))

            let directories = (0..<65).map { "/fictional/bin\($0)" }
            let expected = directories.prefix(64).map { $0 + "/" + agent.rawValue }
            #expect(candidates(agent, policy: .health, path: directories.joined(separator: ":")) == expected)
            #expect(candidates(agent, policy: .usage, path: directories.joined(separator: ":")) == expected + extras(agent))
        }
    }

    @Test func searchPathUsesUTF8ByteBound() {
        let acceptedPaths = ["/" + String(repeating: "x", count: 16_383),
                             "/" + String(repeating: "é", count: 8_191) + "x"]
        for agent in IntegrationAgent.allCases {
            for policy in policies {
                for path in acceptedPaths {
                    #expect(path.utf8.count == 16_384)
                    let executable = URL(fileURLWithPath: path).appendingPathComponent(agent.rawValue)
                    var visited: [String] = []
                    let accepted = AgentPathLocator.executable(
                        agent: agent, policy: policy, searchPath: path, homeDirectory: home,
                        isExecutable: { visited.append($0); return true })
                    #expect(accepted == .found(executable))
                    #expect(visited == [executable.path])

                    visited = []
                    let rejected = AgentPathLocator.executable(
                        agent: agent, policy: policy, searchPath: path + "x", homeDirectory: home,
                        isExecutable: { visited.append($0); return true })
                    #expect(rejected == .invalidSearchPath)
                    #expect(visited.isEmpty)
                }
            }
        }
    }

    @Test func usageAppendsFallbackDirectories() {
        for agent in IntegrationAgent.allCases {
            let pathCandidate = "/fictional/path/" + agent.rawValue
            let fallback = "/usr/local/bin/" + agent.rawValue
            var visited: [String] = []
            let result = AgentPathLocator.executable(
                agent: agent, policy: .usage, searchPath: "/fictional/path", homeDirectory: home,
                isExecutable: { visited.append($0); return $0 == fallback })
            #expect(result == .found(URL(fileURLWithPath: fallback)))
            #expect(visited == [pathCandidate] + extras(agent))
            #expect(candidates(agent, policy: .health, path: "/fictional/path") == [pathCandidate])
        }
    }

    @Test func missingOrEmptyOverrideUsesAgentDefault() {
        for agent in IntegrationAgent.allCases {
            let expected = home.appendingPathComponent(agent == .codex ? ".codex" : ".claude")
            for override: String? in [nil, ""] {
                #expect(AgentPathLocator.configurationDirectory(
                    agent: agent, override: override, homeDirectory: home) == expected)
            }
        }
    }

    @Test func invalidNonemptyOverrideNeverFallsBack() {
        let acceptedPaths = ["/fictional/config", "/",
                             "/" + String(repeating: "x", count: 4_095),
                             "/" + String(repeating: "é", count: 2_047) + "x"]
        for agent in IntegrationAgent.allCases {
            for path in acceptedPaths {
                #expect(AgentPathLocator.configurationDirectory(
                    agent: agent, override: path, homeDirectory: home) == URL(fileURLWithPath: path))
            }
            let invalidPaths = ["relative", "~/.codex", " ",
                                "/" + String(repeating: "x", count: 4_096),
                                "/" + String(repeating: "é", count: 2_047) + "xx"]
            for path in invalidPaths {
                #expect(AgentPathLocator.configurationDirectory(
                    agent: agent, override: path, homeDirectory: home) == nil)
            }
        }
    }
}
