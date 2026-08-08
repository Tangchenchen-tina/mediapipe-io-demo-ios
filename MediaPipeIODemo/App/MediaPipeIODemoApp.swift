import SwiftUI

@main
struct MediaPipeIODemoApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .modelContainer(container.modelContainer)
                .environment(container)
        }
    }
}
