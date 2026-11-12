/// The runtimes Bunlet starts. All always run (decision 0020); the split only orders start and stop.
enum AppFeature: String, CaseIterable, Hashable, Sendable {
    case pet, notch, agents
}
