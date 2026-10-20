import SwiftUI

private enum ShopTab: String, CaseIterable, Identifiable {
    case discover = "Home"
    case friends = "Friends"
    case scroll = "Scroll"
    case saved = "Saved"
    case cart = "Cart"
    case budget = "Budget"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .discover: "safari"
        case .saved: "bookmark"
        case .friends: "person.2"
        case .scroll: "rectangle.stack"
        case .cart: "bag"
        case .budget: "wallet.pass"
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: ShopStore
    @ObservedObject var session: ShopSession
    @State private var tab: ShopTab = .scroll
    @State private var detailProduct: Product?
    @State private var saveProduct: Product?
    @State private var shareProduct: Product?
    @State private var searchPresented = false
    @State private var preferencesPresented = false
    @State private var searchScrollQuery: String?
    @State private var searchResults: [Product] = []
    @State private var accountPresented = false
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            if tab != .scroll { header }
            Group {
                switch tab {
                case .discover:
                    DiscoverView(store: store, onScroll: { tab = .scroll }, onDetails: { detailProduct = $0 })
                case .scroll:
                    ScrollFeedView(
                        store: store,
                        query: searchScrollQuery,
                        searchProducts: searchResults,
                        onDetails: { detailProduct = $0 },
                        onSave: { saveProduct = $0 },
                        onBudget: { tab = .budget },
                        onSearch: { searchPresented = true },
                        onTune: { preferencesPresented = true },
                        onAccount: { accountPresented = true },
                        onExitSearch: { searchScrollQuery = nil }
                    )
                    .id(searchScrollQuery ?? "main-feed")
                case .saved:
                    SavedView(store: store, onDetails: { detailProduct = $0 })
                case .friends:
                    FriendsView(session: session, onDetails: { detailProduct = $0 })
                case .cart:
                    CartView(store: store, onDetails: { detailProduct = $0 }, onScroll: { tab = .scroll })
                case .budget:
                    BudgetView(store: store, onDetails: { detailProduct = $0 })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            tabBar
        }
        .background(ShopTheme.paper)
        .overlay(alignment: .bottom) {
            if let toast {
                Label(toast, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ShopTheme.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.white, in: Capsule())
                    .shadow(color: ShopTheme.plum.opacity(0.2), radius: 16, y: 6)
                    .padding(.bottom, 74)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .sheet(item: $detailProduct) { product in
            ProductDetailsView(product: product, store: store, onSave: {
                detailProduct = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { saveProduct = product }
            }, onShareWithFriend: {
                detailProduct = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { shareProduct = product }
            }, onFeedback: { message in showToast(message) })
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $saveProduct) { product in
            CollectionPickerView(product: product, store: store) { message in
                showToast(message)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $shareProduct) { product in
            FriendShareView(product: product, session: session) { message in
                showToast(message)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $searchPresented) {
            SearchView(store: store, session: session, onDetails: { product in
                searchPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { detailProduct = product }
            }, onScroll: { query, products in
                searchScrollQuery = query
                searchResults = products
                searchPresented = false
                tab = .scroll
            })
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $accountPresented) {
            VStack(alignment: .leading, spacing: 18) {
                SectionKicker(title: "Your account")
                Text(session.displayName)
                    .font(ShopTheme.display(32))
                    .foregroundStyle(ShopTheme.ink)
                Text("Products and recommendations come from \(session.serverURL).")
                    .font(.system(size: 13))
                    .foregroundStyle(ShopTheme.muted)
                if let error = session.errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(ShopTheme.coral)
                }
                Button("Refresh products") {
                    Task { try? await session.loadProducts(into: store) }
                }
                .buttonStyle(PlumButtonStyle(secondary: true))
                Button("Sign out") { accountPresented = false; session.signOut() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ShopTheme.plum)
                Spacer()
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ShopTheme.paper)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $preferencesPresented) {
            FeedPreferencesView(store: store) { showToast("Feed preferences updated") }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("shop")
                    .foregroundStyle(ShopTheme.ink)
                Text("scroll")
                    .foregroundStyle(ShopTheme.plum)
            }
            .font(ShopTheme.display(28))
            .accessibilityLabel("ShopScroll")

            Spacer()

            Button { searchPresented = true } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 42, height: 42)
            }
            .accessibilityLabel("Search products")

            Button { preferencesPresented = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 42, height: 42)
            }
            .accessibilityLabel("Tune feed")

            Button { accountPresented = true } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 19, weight: .medium))
                    .frame(width: 36, height: 42)
            }
            .accessibilityLabel("Account")
        }
        .foregroundStyle(ShopTheme.plum)
        .padding(.leading, 19)
        .padding(.trailing, 9)
        .frame(height: 54)
        .background(ShopTheme.paper)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ShopTab.allCases) { item in
                tabButton(item)
            }
        }
        .frame(height: 64)
        .padding(.horizontal, 7)
        .background {
            ShopTheme.paper
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { ShopTheme.line.frame(height: 1) }
        }
    }

    private func tabButton(_ item: ShopTab) -> some View {
        Button {
            tab = item
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab == item ? "\(item.symbol).fill" : item.symbol)
                    .font(.system(size: 20, weight: .regular))
                    .frame(height: 24)
                Text(item.rawValue)
                    .font(.system(size: 10, weight: tab == item ? .bold : .medium))
            }
            .foregroundStyle(tab == item ? ShopTheme.plum : ShopTheme.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(tab == item ? .isSelected : [])
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { toast = message }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) { toast = nil }
        }
    }
}
