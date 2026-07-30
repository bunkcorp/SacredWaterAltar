import SwiftUI

struct ContentWindow: Scene {
    static let sceneID = "ContentWindow"

    var body: some Scene {
        WindowGroup(id: Self.sceneID) {
            ContentView()
        }
#if os(visionOS)
        .windowStyle(.plain)
        .defaultSize(width: 520, height: 620)
#endif
    }
}
