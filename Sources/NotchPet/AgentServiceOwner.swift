@MainActor
protocol AppFeatureService: AnyObject {
    func start()
    func stop()
}

typealias AppAgentService = AppFeatureService

/// The app creates agent services only after an explicit opt-in.
@MainActor
final class AgentServiceOwner {
    private let factory: () -> any AppAgentService
    private var service: (any AppAgentService)?
    private(set) var isEnabled = false

    init(factory: @escaping () -> any AppAgentService) {
        self.factory = factory
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        if enabled {
            if service == nil { service = factory() }
            service?.start()
        } else {
            service?.stop()
        }
        isEnabled = enabled
    }
}
