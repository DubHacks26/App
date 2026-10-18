import SwiftUI

struct DiscoverView: View {
    @ObservedObject var store: ShopStore
    let onScroll: () -> Void
    let onDetails: (Product) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionKicker(title: "A little discovery, every day")
                    Text("Find your next\nfavorite thing.")
                        .font(ShopTheme.display(42))
                        .foregroundStyle(ShopTheme.ink)
                    Text("A personal scroll of thoughtful finds, shaped by what you love.")
                        .font(.system(size: 15))
                        .foregroundStyle(ShopTheme.muted)
                        .lineSpacing(4)
                }
                .padding(.top, 19)

                if let first = store.products.first {
                    Button(action: onScroll) {
                        ZStack(alignment: .bottomLeading) {
                            ProductArtwork(product: first)
                                .frame(height: 330)
                            LinearGradient(colors: [.clear, ShopTheme.ink.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                            VStack(alignment: .leading, spacing: 7) {
                                Text("YOUR SCROLL STARTS HERE")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.9)
                                Text("One find at a time")
                                    .font(ShopTheme.display(28))
                                Label("Start scrolling", systemImage: "arrow.up.right")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(20)
                        }
                        .frame(height: 330)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text("Fresh finds")
                        .font(ShopTheme.display(29))
                        .foregroundStyle(ShopTheme.ink)
                    Spacer()
                    Button("See all", action: onScroll)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ShopTheme.plum)
                }

                ForEach(store.products.prefix(4)) { product in
                    ProductRow(product: product, accessory: "arrow.up.right") { onDetails(product) }
                }

                Text("The more you heart, save, and skip, the better your feed gets.")
                    .font(.system(size: 13))
                    .foregroundStyle(ShopTheme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .padding(.horizontal, 18)
        }
        .background(ShopTheme.paper)
    }
}

struct SavedView: View {
    @ObservedObject var store: ShopStore
    let onDetails: (Product) -> Void

    @State private var selection = "liked"
    @State private var showingCreate = false
    @State private var collectionName = ""

    private var selectedProducts: [Product] {
        selection == "liked" ? store.likedProducts : store.products(in: selection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    SectionKicker(title: "Keep what you love")
                    Text("Your collections")
                        .font(ShopTheme.display(32))
                        .foregroundStyle(ShopTheme.ink)
                }
                Spacer()
                Button { showingCreate = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ShopTheme.plum)
                        .frame(width: 40, height: 40)
                        .background(ShopTheme.lavender, in: Circle())
                }
                .accessibilityLabel("Create collection")
            }
            .padding(.horizontal, 19)
            .padding(.top, 17)
            .padding(.bottom, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    collectionChip("Liked", id: "liked", count: store.likedProducts.count)
                    ForEach(store.collections) { collection in
                        collectionChip(collection.name, id: collection.id, count: collection.productIDs.count)
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.removeCollection(collection.id)
                                    selection = "liked"
                                } label: { Label("Delete collection", systemImage: "trash") }
                            }
                    }
                }
                .padding(.horizontal, 19)
            }
            .padding(.bottom, 15)

            if selectedProducts.isEmpty {
                EmptyState(
                    icon: selection == "liked" ? "heart" : "bookmark",
                    title: selection == "liked" ? "Nothing hearted yet" : "Nothing saved here yet",
                    message: "Use the actions beside a product as you scroll to keep it here."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(selectedProducts) { product in
                            ProductRow(product: product, accessory: "chevron.right") { onDetails(product) }
                                .contextMenu {
                                    if selection == "liked" {
                                        Button(role: .destructive) { store.toggleLike(product) } label: {
                                            Label("Remove heart", systemImage: "heart.slash")
                                        }
                                    } else {
                                        Button(role: .destructive) { store.toggleSaved(product, in: selection) } label: {
                                            Label("Remove from collection", systemImage: "bookmark.slash")
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(ShopTheme.paper)
        .alert("New collection", isPresented: $showingCreate) {
            TextField("Collection name", text: $collectionName)
            Button("Create") {
                if let collection = store.createCollection(named: collectionName) { selection = collection.id }
                collectionName = ""
            }
            Button("Cancel", role: .cancel) { collectionName = "" }
        } message: {
            Text("Organize the products you save from the scroll.")
        }
    }

    private func collectionChip(_ name: String, id: String, count: Int) -> some View {
        Button { selection = id } label: {
            HStack(spacing: 5) {
                if id == "liked" { Image(systemName: "heart.fill") }
                Text(name)
                Text("\(count)")
                    .opacity(0.65)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(selection == id ? .white : ShopTheme.plum)
            .padding(.horizontal, 14)
            .frame(height: 35)
            .background(selection == id ? ShopTheme.plum : ShopTheme.lavender, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CartView: View {
    @ObservedObject var store: ShopStore
    let onDetails: (Product) -> Void
    let onScroll: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionKicker(title: "Thoughtful shopping")
                    .padding(.top, 17)
                Text("Your cart")
                    .font(ShopTheme.display(34))
                    .foregroundStyle(ShopTheme.ink)

                if store.cartProducts.isEmpty {
                    EmptyState(icon: "bag", title: "Your cart is empty", message: "Open a product’s details to add it here.")
                        .frame(height: 310)
                    Button("Explore the scroll", action: onScroll)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PlumButtonStyle())
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.cartProducts) { product in
                            HStack(spacing: 8) {
                                ProductRow(product: product) { onDetails(product) }
                                Button { store.removeFromCart(product) } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 15))
                                        .foregroundStyle(ShopTheme.plum)
                                        .frame(width: 38, height: 38)
                                }
                                .accessibilityLabel("Remove \(product.name) from cart")
                            }
                        }
                    }

                    VStack(spacing: 11) {
                        summaryRow("Items", value: "\(store.cartProducts.count)")
                        summaryRow("Subtotal", value: store.cartTotal.formatted(.currency(code: "USD")), strong: true)
                        summaryRow("Budget left", value: store.budgetRemaining.formatted(.currency(code: "USD")))
                    }
                    .padding(18)
                    .background(.white, in: RoundedRectangle(cornerRadius: 17))
                    Text("Product prices may change at the retailer.")
                        .font(.system(size: 12))
                        .foregroundStyle(ShopTheme.muted)
                }
            }
            .padding(.horizontal, 19)
            .padding(.bottom, 24)
        }
        .background(ShopTheme.paper)
    }

    private func summaryRow(_ label: String, value: String, strong: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(ShopTheme.muted)
            Spacer()
            Text(value)
                .fontWeight(strong ? .bold : .semibold)
                .foregroundStyle(ShopTheme.ink)
        }
        .font(.system(size: strong ? 16 : 14))
    }
}

struct BudgetView: View {
    @ObservedObject var store: ShopStore
    let onDetails: (Product) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionKicker(title: "Stay in your range")
                    .padding(.top, 17)
                Text("Your budget")
                    .font(ShopTheme.display(34))
                    .foregroundStyle(ShopTheme.ink)

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(store.budgetRemaining.formatted(.currency(code: "USD")))")
                            .font(ShopTheme.display(40))
                            .foregroundStyle(store.cartTotal > store.budgetLimit ? ShopTheme.coral : ShopTheme.plum)
                        Text("left")
                            .font(.system(size: 15))
                            .foregroundStyle(ShopTheme.muted)
                    }
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(ShopTheme.lavender)
                            Capsule().fill(ShopTheme.plum)
                                .frame(width: geometry.size.width * min(store.cartTotal / max(store.budgetLimit, 1), 1))
                        }
                    }
                    .frame(height: 10)
                    HStack {
                        Text("\(store.cartTotal.formatted(.currency(code: "USD"))) in cart")
                        Spacer()
                        Text("\(store.budgetLimit.formatted(.currency(code: "USD"))) budget")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ShopTheme.muted)
                }
                .padding(21)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Set your spending limit")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ShopTheme.ink)
                    Text("The strip above your scroll updates as you add finds to your cart.")
                        .font(.system(size: 13))
                        .foregroundStyle(ShopTheme.muted)
                    Slider(value: $store.budgetLimit, in: 50...1000, step: 25)
                        .tint(ShopTheme.plum)
                        .accessibilityLabel("Budget limit")
                    HStack {
                        Text("$50")
                        Spacer()
                        Text("$1,000")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(ShopTheme.muted)
                }
                .padding(19)
                .background(.white, in: RoundedRectangle(cornerRadius: 18))

                Text("In your cart")
                    .font(ShopTheme.display(25))
                    .foregroundStyle(ShopTheme.ink)
                if store.cartProducts.isEmpty {
                    Text("Your cart is empty. Details on any find will let you add it.")
                        .font(.system(size: 14))
                        .foregroundStyle(ShopTheme.muted)
                } else {
                    ForEach(store.cartProducts) { product in
                        ProductRow(product: product, accessory: "chevron.right") { onDetails(product) }
                    }
                }
            }
            .padding(.horizontal, 19)
            .padding(.bottom, 25)
        }
        .background(ShopTheme.paper)
    }
}

struct SearchView: View {
    @ObservedObject var store: ShopStore
    @ObservedObject var session: ShopSession
    let onDetails: (Product) -> Void
    let onScroll: (String, [Product]) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool
    @State private var query = ""
    @State private var category = "All"
    @State private var sort: ShopSort = .recommended
    @State private var serverResults: [Product] = []
    @State private var loading = false
    @State private var searchError: String?

    private var results: [Product] {
        var items = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? store.products : serverResults
        if category != "All" { items = items.filter { $0.category == category } }
        switch sort {
        case .recommended: break
        case .priceLowToHigh: items.sort { $0.price < $1.price }
        case .priceHighToLow: items.sort { $0.price > $1.price }
        case .topRated: items.sort { $0.rating > $1.rating }
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    SectionKicker(title: "Find your thing")
                    Text("Search")
                        .font(ShopTheme.display(32))
                        .foregroundStyle(ShopTheme.ink)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ShopTheme.plum)
            }
            .padding(.top, 20)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ShopTheme.plum)
                TextField("What are you looking for?", text: $query)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .frame(height: 49)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ShopTheme.line))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(["All"] + store.categories, id: \.self) { item in
                        Button(item) { category = item }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(category == item ? .white : ShopTheme.plum)
                            .padding(.horizontal, 13)
                            .frame(height: 33)
                            .background(category == item ? ShopTheme.plum : ShopTheme.lavender, in: Capsule())
                    }
                }
            }
            .scrollClipDisabled()

            HStack {
                Text(loading ? "Searching server…" : "\(results.count) finds")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ShopTheme.muted)
                Spacer()
                Menu {
                    ForEach(ShopSort.allCases) { option in
                        Button(option.title) { sort = option }
                    }
                } label: {
                    Label(sort.title, systemImage: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ShopTheme.plum)
                }
            }

            if results.isEmpty {
                EmptyState(icon: "magnifyingglass", title: searchError == nil ? "No matching finds" : "Search unavailable", message: searchError ?? "Try another product, brand, or category.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(results) { product in
                            ProductRow(product: product, accessory: "arrow.up.right") { onDetails(product) }
                        }
                    }
                    .padding(.bottom, 15)
                }
            }

            Button {
                store.searchText = query
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Task { await session.submitSearch(query, into: store) }
                }
                onScroll(query, results)
            } label: {
                Label(query.isEmpty ? "Scroll all finds" : "Scroll these finds", systemImage: "rectangle.stack")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlumButtonStyle())
            .disabled(results.isEmpty)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 19)
        .background(ShopTheme.paper)
        .onAppear { query = store.searchText }
        .task(id: query) {
            let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                serverResults = []
                searchError = nil
                loading = false
                return
            }
            loading = true
            searchError = nil
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            do {
                let fetched = try await session.searchProducts(text)
                guard !Task.isCancelled else { return }
                serverResults = fetched
            } catch {
                guard !Task.isCancelled else { return }
                serverResults = []
                searchError = error.localizedDescription
            }
            loading = false
        }
    }
}

struct FeedPreferencesView: View {
    @ObservedObject var store: ShopStore
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category = "All"
    @State private var sort: ShopSort = .recommended

    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            SectionKicker(title: "Make it yours")
                .padding(.top, 18)
            Text("Tune your feed")
                .font(ShopTheme.display(32))
                .foregroundStyle(ShopTheme.ink)
            Text("Choose the kinds of finds you want to see. Hearts and feedback continue to shape the order.")
                .font(.system(size: 14))
                .foregroundStyle(ShopTheme.muted)
                .lineSpacing(4)

            Text("Category")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ShopTheme.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["All"] + store.categories, id: \.self) { item in
                        Button(item) { category = item }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(category == item ? .white : ShopTheme.plum)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(category == item ? ShopTheme.plum : ShopTheme.lavender, in: Capsule())
                    }
                }
            }
            .scrollClipDisabled()

            Text("Order")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ShopTheme.ink)
            Picker("Order", selection: $sort) {
                ForEach(ShopSort.allCases) { option in Text(option.title).tag(option) }
            }
            .pickerStyle(.menu)
            .tint(ShopTheme.plum)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 13))

            Spacer()

            Button {
                store.selectedCategory = category == "All" ? nil : category
                store.selectedSort = sort
                onApply()
                dismiss()
            } label: {
                Text("Apply to my scroll").frame(maxWidth: .infinity)
            }
            .buttonStyle(PlumButtonStyle())
            .padding(.bottom, 10)
        }
        .padding(.horizontal, 19)
        .background(ShopTheme.paper)
        .onAppear {
            category = store.selectedCategory ?? "All"
            sort = store.selectedSort
        }
    }
}
