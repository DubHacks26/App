import SwiftUI

@main
struct ShopScrollApp: App {
    @StateObject private var store = ShopStore.shared
    @StateObject private var session = ShopSession()
    @State private var didStart = false

    var body: some Scene {
        WindowGroup {
            Group {
                if session.restoring || session.loadingProducts && !session.catalogReady {
                    VStack(spacing: 13) {
                        ProgressView().tint(ShopTheme.plum)
                        Text("Finding your next favorite…")
                            .font(ShopTheme.display(25))
                            .foregroundStyle(ShopTheme.ink)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ShopTheme.paper)
                } else if session.signedIn && session.catalogReady {
                    ContentView(store: store, session: session)
                } else if session.signedIn {
                    ServerProblemView(session: session, store: store)
                } else {
                    SignInView(session: session, store: store)
                }
            }
                .task {
                    guard !didStart else { return }
                    didStart = true
                    store.onAction = { event in Task { await session.persist(event, into: store) } }
                    await session.restore(into: store)
                }
                .preferredColorScheme(.light)
        }
    }
}
