#if canImport(SwiftUI)
import SwiftUI

/// The root view for FrameWise.
///
/// This starter body will become the camera shell. The view should compose
/// screen-level pieces, while camera setup and state transitions stay in the
/// view model and service layers.
struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}
#endif
