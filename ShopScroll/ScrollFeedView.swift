import SwiftUI

struct ScrollFeedView: View {
    @ObservedObject var store: ShopStore
    let query: String?
    let searchProducts: [Product]
    let onDetails: (Product) -> Void
    let onSave: (Product) -> Void
    let onBudget: () -> Void
    let onSearch: () -> Void
    let onTune: () -> Void
    let onAccount: () -> Void
    let onExitSearch: () -> Void

    @State private var queue: [Product] = []
    @State private var cursor = 0
    @State private var dragX: CGFloat = 0
    @State private var dragY: CGFloat = 0
    @State private var dragAxis: Axis?
    @State private var expanded = false
    @State private var heartPulse = false
    @State private var boundaryMessage: String?
    @State private var shownAt = Date.now
    @State private var transitioning = false

    private var sourceProducts: [Product] {
        if let query, !query.isEmpty {
            return searchProducts
        }
        return store.search("", category: store.selectedCategory, sort: store.selectedSort)
    }

    private var products: [Product] { queue.isEmpty ? sourceProducts : queue }
    private var incomingIDs: [String] { sourceProducts.map(\.id) }

    var body: some View {
        VStack(spacing: 0) {
            if let query, !query.isEmpty {
                HStack(spacing: 4) {
                    Text("Search scroll")
                    Text("“\(query)”").fontWeight(.bold).lineLimit(1)
                    Spacer(minLength: 6)
                    Button("Back to your feed", action: onExitSearch)
                        .fontWeight(.semibold)
                        .foregroundStyle(ShopTheme.plum)
                }
                .font(.system(size: 12))
                .foregroundStyle(ShopTheme.ink)
                .padding(.horizontal, 12)
                .frame(height: 43)
                .background(ShopTheme.paper)
            }

            Button(action: onBudget) { budgetStrip }
                .buttonStyle(.plain)
                .accessibilityLabel("Budget: \(store.budgetRemaining.formatted(.currency(code: "USD"))) remaining. Open budget")

            if products.isEmpty {
                EmptyState(
                    icon: "magnifyingglass",
                    title: query == nil ? "No finds in your feed" : "No matching finds",
                    message: query == nil ? "Try changing your feed preferences." : "Try a different search to keep scrolling."
                )
            } else {
                GeometryReader { geometry in
                    ZStack {
                        ForEach(visibleIndices, id: \.self) { index in
                            let product = products[index]
                            let active = index == cursor
                            ProductReelCard(
                                product: product,
                                position: index + 1,
                                total: products.count,
                                isLiked: store.isLiked(product.id),
                                isSaved: store.isSaved(product.id),
                                expanded: active && expanded,
                                heartPulse: active && heartPulse,
                                horizontalProgress: active ? min(abs(dragX) / 90, 1) : 0,
                                onExpand: { if active { withAnimation(.easeInOut(duration: 0.26)) { expanded.toggle() } } },
                                onHeart: { heart(product) },
                                onSave: { onSave(product) },
                                onDetails: { onDetails(product) }
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(
                                x: active ? dragX * 0.62 : 0,
                                y: CGFloat(index - cursor) * geometry.size.height + dragY
                            )
                            .rotationEffect(.degrees(active ? Double(dragX / 45) : 0))
                            .zIndex(active ? 1 : 0)
                            .accessibilityHidden(!active)
                        }

                        if let boundaryMessage {
                            Text(boundaryMessage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ShopTheme.ink)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 10)
                                .background(.white, in: Capsule())
                                .shadow(color: .black.opacity(0.15), radius: 12)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                                .padding(.bottom, 18)
                                .zIndex(4)
                        }

                        HStack(spacing: 9) {
                            Spacer()
                            floatingControl("magnifyingglass", label: "Search products", action: onSearch)
                            floatingControl("slider.horizontal.3", label: "Tune feed", action: onTune)
                            floatingControl("person.crop.circle", label: "Account", action: onAccount)
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.horizontal, 13)
                        .padding(.top, 12)
                        .zIndex(5)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .contentShape(Rectangle())
                    .simultaneousGesture(dragGesture(in: geometry.size))
                    .accessibilityAction(named: "Next product") { moveTo(cursor + 1) }
                    .accessibilityAction(named: "Previous product") { moveTo(cursor - 1) }
                }
                .background(ShopTheme.ink)
            }
        }
        .onAppear {
            syncQueue(with: sourceProducts)
            shownAt = .now
        }
        .onChange(of: incomingIDs) { syncQueue(with: sourceProducts) }
    }

    private var visibleIndices: [Int] {
        guard !products.isEmpty else { return [] }
        return Array(max(0, cursor - 1)...min(products.count - 1, cursor + 1))
    }

    private var budgetStrip: some View {
        HStack(spacing: 9) {
            Text("In cart")
            Text(store.cartTotal.formatted(.currency(code: "USD"))).fontWeight(.bold).foregroundStyle(ShopTheme.ink)
            Text("Budget")
            Text(store.budgetLimit.formatted(.currency(code: "USD"))).fontWeight(.bold).foregroundStyle(ShopTheme.ink)
            Spacer(minLength: 0)
            Text("\(store.budgetRemaining.formatted(.currency(code: "USD"))) left")
                .fontWeight(.bold)
                .foregroundStyle(store.cartTotal > store.budgetLimit ? ShopTheme.coral : ShopTheme.ink)
        }
        .font(.system(size: 10))
        .foregroundStyle(ShopTheme.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(ShopTheme.paper)
        .overlay(alignment: .bottom) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    ShopTheme.line
                    ShopTheme.plum
                        .frame(width: proxy.size.width * min(store.cartTotal / max(store.budgetLimit, 1), 1))
                }
            }
            .frame(height: 3)
        }
    }

    private func floatingControl(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ShopTheme.plum)
                .frame(width: 39, height: 39)
                .background(.white.opacity(0.93), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !transitioning else { return }
                let x = value.translation.width
                let y = value.translation.height
                if dragAxis == nil {
                    if abs(x) > abs(y) * 1.2 { dragAxis = .horizontal }
                    else if abs(y) > abs(x) * 1.2 { dragAxis = .vertical }
                }
                if dragAxis == .horizontal { dragX = x }
                if dragAxis == .vertical {
                    let atEdge = (cursor == 0 && y > 0) || (cursor == products.count - 1 && y < 0)
                    dragY = y * (atEdge ? 0.24 : 1)
                }
            }
            .onEnded { value in
                guard !transitioning else { return }
                let x = value.translation.width
                let y = value.translation.height
                let axis = dragAxis ?? (abs(x) > abs(y) ? Axis.horizontal : .vertical)
                dragAxis = nil
                if axis == .horizontal && abs(x) > 90 {
                    swipeHeart(direction: x < 0 ? -1 : 1, width: size.width)
                    return
                }
                if axis == .vertical {
                    let threshold = max(48, size.height * 0.08)
                    let quickFlick = abs(value.predictedEndTranslation.height) > threshold * 1.6 && abs(y) >= 28
                    if abs(y) > threshold || quickFlick {
                        moveTo(cursor + (y < 0 ? 1 : -1))
                    }
                }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    dragX = 0
                    dragY = 0
                }
            }
    }

    private func syncQueue(with incoming: [Product]) {
        guard !incoming.isEmpty else {
            queue = []
            cursor = 0
            return
        }
        if queue.isEmpty {
            queue = incoming
            cursor = 0
            return
        }
        // Keep visited cards fixed while recommendations reorder the unseen tail.
        let pinned = Array(queue.prefix(min(cursor + 1, queue.count)))
        let pinnedIDs = Set(pinned.map(\.id))
        queue = pinned + incoming.filter { !pinnedIDs.contains($0.id) }
        cursor = min(cursor, queue.count - 1)
    }

    private func moveTo(_ nextIndex: Int) {
        guard !transitioning, let current = products[safe: cursor] else { return }
        guard nextIndex >= 0 && nextIndex < products.count else {
            showBoundary(nextIndex < 0 ? "You’re at the first find" : "You’re at the end of this scroll")
            return
        }
        if nextIndex > cursor {
            store.recordSkip(current, dwellMilliseconds: Int(max(0, Date.now.timeIntervalSince(shownAt) * 1000)))
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            cursor = nextIndex
            dragY = 0
            dragX = 0
        }
        shownAt = .now
        expanded = false
    }

    private func heart(_ product: Product) {
        store.toggleLike(product)
        heartPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { heartPulse = false }
    }

    private func swipeHeart(direction: Int, width: CGFloat) {
        guard let product = products[safe: cursor] else { return }
        heart(product)
        if cursor == products.count - 1 {
            showBoundary("You’re at the end of this scroll")
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { dragX = 0 }
            return
        }
        transitioning = true
        withAnimation(.easeOut(duration: 0.3)) { dragX = CGFloat(direction) * (width + 130) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dragX = 0
            dragY = 0
            expanded = false
            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) { cursor += 1 }
            shownAt = .now
            transitioning = false
        }
    }

    private func showBoundary(_ message: String) {
        withAnimation { boundaryMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if boundaryMessage == message { withAnimation { boundaryMessage = nil } }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

private struct ProductReelCard: View {
    let product: Product
    let position: Int
    let total: Int
    let isLiked: Bool
    let isSaved: Bool
    let expanded: Bool
    let heartPulse: Bool
    let horizontalProgress: CGFloat
    let onExpand: () -> Void
    let onHeart: () -> Void
    let onSave: () -> Void
    let onDetails: () -> Void

    var body: some View {
        ZStack {
            ShopTheme.ink
            ProductArtwork(product: product, fit: expanded)
                .onTapGesture(count: 2, perform: onHeart)
                .onTapGesture(perform: onExpand)

            if !expanded {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.28), location: 0),
                        .init(color: .clear, location: 0.24),
                        .init(color: .clear, location: 0.48),
                        .init(color: ShopTheme.ink.opacity(0.92), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack {
                    Spacer()
                    HStack(alignment: .bottom, spacing: 6) {
                        VStack(alignment: .leading, spacing: 11) {
                            Text(product.title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(Color(red: 0.97, green: 0.77, blue: 0.47))
                                Text(product.rating.formatted(.number.precision(.fractionLength(1))))
                                    .fontWeight(.bold)
                                Text("(\(product.reviews.formatted()))")
                                    .foregroundStyle(.white.opacity(0.75))
                                Spacer(minLength: 4)
                                Button(action: onDetails) {
                                    HStack(spacing: 3) {
                                        Text("View details")
                                        Image(systemName: "arrow.right")
                                    }
                                    .fontWeight(.bold)
                                }
                                .buttonStyle(.plain)
                            }
                            .font(.system(size: 12))
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 22) {
                            railButton(symbol: isLiked ? "heart.fill" : "heart", label: isLiked ? "Hearted" : "Heart", tint: isLiked ? ShopTheme.coral : .white, action: onHeart)
                            ShareLink(item: shareText) {
                                railLabel(symbol: "square.and.arrow.up", label: "Share", tint: .white)
                            }
                            .buttonStyle(.plain)
                            railButton(symbol: isSaved ? "bookmark.fill" : "bookmark", label: isSaved ? "Saved" : "Save", tint: .white, action: onSave)
                        }
                        .frame(width: 55)
                        .padding(.bottom, 70)
                    }
                }
                .padding(.leading, 20)
                .padding(.trailing, 12)
                .padding(.bottom, 19)
                .foregroundStyle(.white)
            } else {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onExpand) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.55), in: Circle())
                        }
                        .accessibilityLabel("Close expanded image")
                    }
                    Spacer()
                }
                .padding(16)
            }

            if heartPulse || horizontalProgress > 0 {
                Image(systemName: "heart.fill")
                    .font(.system(size: 45, weight: .bold))
                    .foregroundStyle(ShopTheme.coral)
                    .frame(width: 104, height: 104)
                    .background(.white.opacity(0.96), in: Circle())
                    .scaleEffect(heartPulse ? 1.08 : 0.45 + horizontalProgress * 0.55)
                    .opacity(heartPulse ? 1 : horizontalProgress)
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Product \(position) of \(total): \(product.name)")
    }

    private var shareText: String {
        if let url = product.productURL, !url.isEmpty {
            return "Found \(product.name) on ShopScroll: \(url)"
        }
        return "Found \(product.name) on ShopScroll"
    }

    private func railButton(symbol: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            railLabel(symbol: symbol, label: label, tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) \(product.name)")
    }

    private func railLabel(symbol: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(tint)
                .shadow(color: .black.opacity(0.25), radius: 5)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .shadow(color: .black.opacity(0.5), radius: 4)
        }
        .frame(width: 56, height: 49)
    }
}
