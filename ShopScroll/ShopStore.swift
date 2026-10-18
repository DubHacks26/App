import Combine
import Foundation

/// Account-scoped local state shared by Scroll, Collections, Cart, Search, and Budget.
/// Products are replaced by the server catalog after sign-in.
@MainActor
final class ShopStore: ObservableObject {
    static let shared = ShopStore()

    @Published var products: [Product] { didSet { persist() } }
    @Published private(set) var likedIDs: Set<String> { didSet { persist() } }
    @Published private(set) var collections: [ShopCollection] { didSet { persist() } }
    @Published private(set) var cartIDs: Set<String> { didSet { persist() } }
    @Published var budgetLimit: Double { didSet { persist() } }
    @Published private(set) var feedback: [ShopFeedback] { didSet { persist() } }
    @Published private(set) var history: [ShopHistoryEvent] { didSet { persist() } }
    @Published var searchText: String
    @Published var selectedCategory: String? { didSet { persist() } }
    @Published var selectedSort: ShopSort { didSet { persist() } }

    private let defaults: UserDefaults
    var onAction: ((ShopHistoryEvent) -> Void)?
    private static let storagePrefix = "shopscroll.localState.v1"
    private var storageKey = ShopStore.storagePrefix
    private var activeAccountID: String?

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
        let saved = userDefaults.data(forKey: Self.storagePrefix)
            .flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) }

        products = saved?.products.isEmpty == false ? saved!.products : Product.demoProducts
        likedIDs = saved?.likedIDs ?? []
        collections = saved?.collections ?? [ShopCollection(id: "saved", name: "Saved")]
        cartIDs = saved?.cartIDs ?? []
        budgetLimit = saved?.budgetLimit ?? 400
        feedback = saved?.feedback ?? []
        history = saved?.history ?? []
        searchText = ""
        selectedCategory = saved?.selectedCategory
        selectedSort = saved?.selectedSort ?? .recommended
    }

    func configureAccount(_ userID: String) {
        guard activeAccountID != userID else { return }
        activeAccountID = userID
        storageKey = "\(Self.storagePrefix):\(userID)"
        let saved = defaults.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) }
        products = saved?.products.isEmpty == false ? saved!.products : Product.demoProducts
        likedIDs = saved?.likedIDs ?? []
        collections = saved?.collections ?? [ShopCollection(id: "saved", name: "Saved")]
        cartIDs = saved?.cartIDs ?? []
        budgetLimit = saved?.budgetLimit ?? 400
        feedback = saved?.feedback ?? []
        history = saved?.history ?? []
        selectedCategory = saved?.selectedCategory
        selectedSort = saved?.selectedSort ?? .recommended
        searchText = ""
    }

    var categories: [String] {
        Array(Set(products.map(\.category))).sorted()
    }

    var filteredProducts: [Product] {
        search(searchText, category: selectedCategory, sort: selectedSort)
    }

    var likedProducts: [Product] {
        products.filter { likedIDs.contains($0.id) }
    }

    var savedProductIDs: Set<String> {
        Set(collections.flatMap(\.productIDs))
    }

    var savedProducts: [Product] {
        products.filter { savedProductIDs.contains($0.id) }
    }

    var cartProducts: [Product] {
        products.filter { cartIDs.contains($0.id) }
    }

    var cartTotal: Double {
        cartProducts.reduce(0) { $0 + $1.price }
    }

    var budgetRemaining: Double {
        max(0, budgetLimit - cartTotal)
    }

    var historyProducts: [Product] {
        var seen = Set<String>()
        return history.reversed().compactMap { event in
            guard seen.insert(event.productID).inserted else { return nil }
            return product(id: event.productID)
        }
    }

    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }

    func search(_ query: String, category: String? = nil, sort: ShopSort = .recommended) -> [Product] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = products.filter { product in
            let matchesCategory = category == nil || category == "All"
                || product.category.localizedCaseInsensitiveCompare(category!) == .orderedSame
            guard matchesCategory else { return false }
            guard !trimmed.isEmpty else { return true }
            return [product.name, product.title, product.brand, product.description,
                    product.category, product.subcategory ?? ""]
                .contains { $0.localizedStandardContains(trimmed) }
                || product.tags.contains { $0.localizedStandardContains(trimmed) }
        }

        switch sort {
        case .recommended:
            break // Preserve the order returned by the server recommender.
        case .priceLowToHigh:
            result.sort { $0.price == $1.price ? $0.name < $1.name : $0.price < $1.price }
        case .priceHighToLow:
            result.sort { $0.price == $1.price ? $0.name < $1.name : $0.price > $1.price }
        case .topRated:
            result.sort { $0.rating == $1.rating ? $0.reviews > $1.reviews : $0.rating > $1.rating }
        }
        return result
    }

    func isLiked(_ productID: String) -> Bool { likedIDs.contains(productID) }
    func isSaved(_ productID: String) -> Bool { savedProductIDs.contains(productID) }
    func isInCart(_ productID: String) -> Bool { cartIDs.contains(productID) }

    func toggleLike(_ productID: String) {
        if likedIDs.contains(productID) {
            likedIDs.remove(productID)
            record(productID, action: .unlike)
        } else {
            likedIDs.insert(productID)
            record(productID, action: .like)
        }
    }

    func toggleLike(_ product: Product) { toggleLike(product.id) }

    @discardableResult
    func createCollection(named name: String) -> ShopCollection? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let existing = collections.first(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let collection = ShopCollection(name: trimmed)
        collections.append(collection)
        return collection
    }

    func removeCollection(_ collectionID: String) {
        let previouslySaved = savedProductIDs
        collections.removeAll { $0.id == collectionID }
        for id in previouslySaved.subtracting(savedProductIDs) {
            record(id, action: .unsave)
        }
    }

    func toggleSaved(_ productID: String, in collectionID: String) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        let wasSaved = isSaved(productID)
        if collections[index].productIDs.contains(productID) {
            collections[index].productIDs.removeAll { $0 == productID }
        } else {
            collections[index].productIDs.append(productID)
        }
        let isNowSaved = isSaved(productID)
        if wasSaved != isNowSaved { record(productID, action: isNowSaved ? .save : .unsave) }
    }

    func toggleSaved(_ product: Product, in collectionID: String) {
        toggleSaved(product.id, in: collectionID)
    }

    func products(in collectionID: String) -> [Product] {
        guard let collection = collections.first(where: { $0.id == collectionID }) else { return [] }
        let lookup = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        return collection.productIDs.compactMap { lookup[$0] }
    }

    func addToCart(_ productID: String) {
        guard !cartIDs.contains(productID) else { return }
        cartIDs.insert(productID)
        record(productID, action: .addToCart)
    }

    func addToCart(_ product: Product) { addToCart(product.id) }

    func removeFromCart(_ productID: String) {
        guard cartIDs.contains(productID) else { return }
        cartIDs.remove(productID)
        record(productID, action: .removeFromCart)
    }

    func removeFromCart(_ product: Product) { removeFromCart(product.id) }

    func recordSkip(_ productID: String, dwellMilliseconds: Int? = nil) {
        record(productID, action: .skip, dwellMilliseconds: dwellMilliseconds)
        addFeedback(productID, action: .skip)
    }

    func recordSkip(_ product: Product, dwellMilliseconds: Int? = nil) {
        recordSkip(product.id, dwellMilliseconds: dwellMilliseconds)
    }

    func recordTooExpensive(_ productID: String) {
        record(productID, action: .tooExpensive)
        addFeedback(productID, action: .tooExpensive)
    }

    func recordTooExpensive(_ product: Product) { recordTooExpensive(product.id) }

    func recordLessOfCategory(_ productID: String) {
        record(productID, action: .lessCategory)
        addFeedback(productID, action: .lessCategory)
    }

    func recordLessOfCategory(_ product: Product) { recordLessOfCategory(product.id) }

    /// Accepts the web app's `{ "products": [...] }` catalog response or a bare array.
    func importCatalog(from data: Data) throws {
        let incoming = try Product.decodeCatalog(from: data)
        replaceProducts(with: incoming)
    }

    func replaceProducts(with incoming: [Product]) {
        guard !incoming.isEmpty else { return }
        var seen = Set<String>()
        products = incoming.filter { seen.insert($0.id).inserted }
    }

    private func record(_ productID: String, action: ShopAction, dwellMilliseconds: Int? = nil) {
        let event = ShopHistoryEvent(
            productID: productID,
            action: action,
            dwellMilliseconds: dwellMilliseconds.map { max(0, $0) }
        )
        history.append(event)
        if history.count > 500 { history.removeFirst(history.count - 500) }
        onAction?(event)
    }

    private func addFeedback(_ productID: String, action: ShopAction) {
        feedback.append(ShopFeedback(
            productID: productID,
            category: product(id: productID)?.category ?? "Other",
            action: action
        ))
        if feedback.count > 200 { feedback.removeFirst(feedback.count - 200) }
    }

    private func persist() {
        let state = Snapshot(
            products: products, likedIDs: likedIDs, collections: collections,
            cartIDs: cartIDs, budgetLimit: max(0, budgetLimit),
            feedback: feedback, history: history,
            selectedCategory: selectedCategory, selectedSort: selectedSort
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

private struct Snapshot: Codable {
    let products: [Product]
    let likedIDs: Set<String>
    let collections: [ShopCollection]
    let cartIDs: Set<String>
    let budgetLimit: Double
    let feedback: [ShopFeedback]
    let history: [ShopHistoryEvent]
    let selectedCategory: String?
    let selectedSort: ShopSort
}
