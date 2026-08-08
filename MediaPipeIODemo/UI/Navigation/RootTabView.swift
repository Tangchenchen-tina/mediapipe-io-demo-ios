import SwiftUI

struct RootTabView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        TabView {
            ChatListView(container: container)
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill") }

            ArchiveListView(container: container)
                .tabItem { Label("Archive", systemImage: "doc.text.fill") }

            EmailListView(container: container)
                .tabItem { Label("Email", systemImage: "envelope.fill") }
        }
    }
}
