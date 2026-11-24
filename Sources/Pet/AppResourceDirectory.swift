import Foundation

public enum AppResourceDirectory {
    /// Returns the directory that holds the files of a SwiftPM resource bundle.
    ///
    /// SwiftPM's generated `Bundle.module` looks beside the `.app` and then at the
    /// absolute build path of the machine that compiled it. A packaged app keeps its
    /// resource bundles in `Contents/Resources`, so on any other Mac `Bundle.module`
    /// finds neither and traps. In an app, resolve only that app's own copy, and
    /// return nil when it is missing so callers degrade instead of crashing.
    /// Outside an app (tests, `swift run`), use the caller's `Bundle.module` location.
    public static func locate(_ bundleName: String, in appBundle: Bundle,
                              otherwise fallback: @autoclosure () -> URL?) -> URL? {
        guard appBundle.bundleURL.pathExtension == "app" else { return fallback() }
        // SwiftPM toolchains emit both flat and Contents/Resources bundle layouts.
        return appBundle.resourceURL
            .map { $0.appendingPathComponent(bundleName) }
            .flatMap { Bundle(url: $0)?.resourceURL ?? $0 }
    }
}
