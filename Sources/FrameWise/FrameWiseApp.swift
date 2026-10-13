#if canImport(SwiftUI)
import SwiftUI

/// The application entry point.
///
/// `WindowGroup` owns the app scene, while `ContentView` owns the first
/// screen the user sees. Keeping that composition here makes the lifecycle
/// easy to find without mixing it with camera-session code.
@main
struct FrameWiseApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
#endif
