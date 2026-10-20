import Foundation

/// The shape used by the local feed. Its decoder also accepts the web app's
/// `/user/catalog` rows (snake case), captured Amazon rows (camel case), and
/// the older demo product shape.
struct Product: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let brand: String
    let title: String
    let description: String
    let category: String
    let subcategory: String?
    let price: Double
    let rating: Double
    let reviews: Int
    let imageURL: String
    let productURL: String?
    let tags: [String]
    let localImageName: String?

    init(
        id: String,
        name: String,
        brand: String,
        title: String? = nil,
        description: String,
        category: String,
        subcategory: String? = nil,
        price: Double,
        rating: Double,
        reviews: Int,
        imageURL: String,
        productURL: String? = nil,
        tags: [String] = [],
        localImageName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.title = title ?? name
        self.description = description
        self.category = category
        self.subcategory = subcategory
        self.price = price
        self.rating = rating
        self.reviews = reviews
        self.imageURL = imageURL
        self.productURL = productURL
        self.tags = tags
        self.localImageName = localImageName
    }

    var formattedPrice: String { price.formatted(.currency(code: "USD")) }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: ProductKey.self)
        let rawTitle = values.string("title", "name") ?? "Untitled find"
        let rawName = values.string("name") ?? rawTitle
        let rawTags = values.strings("hashtags") + values.strings("tags")
        let categories = values.strings("categories")
        let suppliedCategory = values.string("category", "main_category", "mainCategory")
            ?? categories.first

        id = values.string("asin", "id") ?? rawTitle
        name = rawName
        brand = values.string("brand") ?? "Independent brand"
        title = rawTitle
        description = values.string("summary", "description") ?? rawTitle
        category = Self.inferCategory(suppliedCategory, title: rawTitle, tags: rawTags)
        subcategory = values.string("subcategory", "sub_category")

        if let cents = values.number("price_cents", "priceCents") {
            price = max(0, cents / 100)
        } else {
            price = max(0, values.number("price") ?? 0)
        }
        rating = min(5, max(0, values.number("rating") ?? 0))
        reviews = max(0, Int(values.number("review_count", "reviewCount", "reviews") ?? 0))
        imageURL = values.string("image_url", "imageURL", "imageUrl", "image") ?? ""
        productURL = values.string("product_url", "productURL", "productUrl")
        tags = Array(Set(rawTags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })).sorted()
        localImageName = values.string("localImageName", "local_image_name")
            ?? (Self.bundledImageIDs.contains(id) ? id : nil)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: ProductKey.self)
        try values.encode(id, forKey: ProductKey("id"))
        try values.encode(name, forKey: ProductKey("name"))
        try values.encode(brand, forKey: ProductKey("brand"))
        try values.encode(title, forKey: ProductKey("title"))
        try values.encode(description, forKey: ProductKey("description"))
        try values.encode(category, forKey: ProductKey("category"))
        try values.encodeIfPresent(subcategory, forKey: ProductKey("subcategory"))
        try values.encode(price, forKey: ProductKey("price"))
        try values.encode(rating, forKey: ProductKey("rating"))
        try values.encode(reviews, forKey: ProductKey("reviews"))
        try values.encode(imageURL, forKey: ProductKey("imageURL"))
        try values.encodeIfPresent(productURL, forKey: ProductKey("productURL"))
        try values.encode(tags, forKey: ProductKey("tags"))
        try values.encodeIfPresent(localImageName, forKey: ProductKey("localImageName"))
    }

    static func decodeCatalog(from data: Data) throws -> [Product] {
        let decoder = JSONDecoder()
        if let products = try? decoder.decode([Product].self, from: data) { return products }
        return try decoder.decode(CatalogEnvelope.self, from: data).products
    }

    private static let bundledImageIDs: Set<String> = [
        "headphones", "lamp", "runners", "skincare", "vase", "tote",
        "speaker", "sunglasses", "mug", "throw",
    ]

    private static func inferCategory(_ raw: String?, title: String, tags: [String]) -> String {
        let category = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let source = ([category, title] + tags).joined(separator: " ").lowercased()
        if source.range(of: "beauty|skincare|skin care|makeup|serum|moisturizer", options: .regularExpression) != nil { return "Beauty" }
        if source.range(of: "shoe|sneaker|runner|clothing|fashion|tote|sunglasses|jacket|dress", options: .regularExpression) != nil { return "Fashion" }
        if source.range(of: "headphone|speaker|audio|tech|electronic|computer|phone|camera", options: .regularExpression) != nil { return "Tech" }
        if source.range(of: "lamp|home|decor|kitchen|vase|mug|throw|furniture", options: .regularExpression) != nil { return "Home" }
        return category.isEmpty ? "Other" : category
    }

    static let demoProducts: [Product] = [
        Product(
            id: "headphones", name: "Studio Pro Headphones", brand: "Auraline",
            description: "Immersive sound, cloud-soft cushions, and 40 hours of listening in a warm neutral finish.",
            category: "Tech", subcategory: "Audio", price: 89, rating: 4.8, reviews: 1_240,
            imageURL: "https://images.unsplash.com/photo-1766338055584-5ffe426a7e57?auto=format&fit=crop&w=1200&q=85",
            tags: ["minimalist", "practical", "neutral", "audio"], localImageName: "headphones"
        ),
        Product(
            id: "lamp", name: "Noma Glow Lamp", brand: "Hearth & Form",
            description: "A sculptural bedside lamp with three warm light settings and a compact linen shade.",
            category: "Home", subcategory: "Lighting", price: 64, rating: 4.7, reviews: 684,
            imageURL: "https://images.unsplash.com/photo-1699979306075-1b4c943a3b16?auto=format&fit=crop&w=1200&q=85",
            tags: ["minimalist", "aesthetic", "white", "neutral"], localImageName: "lamp"
        ),
        Product(
            id: "runners", name: "Cloudline Runners", brand: "North & Other",
            description: "Everyday trainers made with recycled mesh, a cushioned sole, and easy neutral styling.",
            category: "Fashion", subcategory: "Footwear", price: 76, rating: 4.6, reviews: 932,
            imageURL: "https://images.unsplash.com/photo-1632761486768-5a50cf7329cf?auto=format&fit=crop&w=1200&q=85",
            tags: ["sustainable", "practical", "white", "footwear"], localImageName: "runners"
        ),
        Product(
            id: "skincare", name: "Daily Ritual Set", brand: "Morrow Skin",
            description: "A simple three-step hydration ritual with cleanser, serum, and barrier cream.",
            category: "Beauty", subcategory: "Skincare", price: 42, rating: 4.9, reviews: 508,
            imageURL: "https://images.unsplash.com/photo-1779117691346-5de09d89a73f?auto=format&fit=crop&w=1200&q=85",
            tags: ["minimalist", "budget-friendly", "pink", "skincare"], localImageName: "skincare"
        ),
        Product(
            id: "vase", name: "Arc Ceramic Vase", brand: "Hearth & Form",
            description: "A softly curved stoneware vase that makes a quiet statement on any shelf.",
            category: "Home", subcategory: "Decor", price: 48, rating: 4.8, reviews: 327,
            imageURL: "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?auto=format&fit=crop&w=1200&q=85",
            tags: ["aesthetic", "minimalist", "neutral", "decor"], localImageName: "vase"
        ),
        Product(
            id: "tote", name: "Everyday Canvas Tote", brand: "North & Other",
            description: "A roomy, durable carryall for the market, studio, and everywhere between.",
            category: "Fashion", subcategory: "Accessories", price: 36, rating: 4.7, reviews: 418,
            imageURL: "https://images.unsplash.com/photo-1544816155-12df9643f363?auto=format&fit=crop&w=1200&q=85",
            tags: ["sustainable", "practical", "neutral", "accessories"], localImageName: "tote"
        ),
        Product(
            id: "speaker", name: "Halo Mini Speaker", brand: "Auraline",
            description: "Surprisingly full sound in a portable shape that fits anywhere.",
            category: "Tech", subcategory: "Audio", price: 58, rating: 4.5, reviews: 763,
            imageURL: "https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?auto=format&fit=crop&w=1200&q=85",
            tags: ["practical", "audio", "portable", "tech"], localImageName: "speaker"
        ),
        Product(
            id: "sunglasses", name: "Soleil Sunglasses", brand: "Mira Studio",
            description: "A modern everyday frame with warm tinted lenses and an easy, timeless feel.",
            category: "Fashion", subcategory: "Accessories", price: 54, rating: 4.6, reviews: 291,
            imageURL: "https://images.unsplash.com/photo-1511499767150-a48a237f0083?auto=format&fit=crop&w=1200&q=85",
            tags: ["aesthetic", "accessories", "summer", "fashion"], localImageName: "sunglasses"
        ),
        Product(
            id: "mug", name: "Atlas Travel Mug", brand: "Fieldwork",
            description: "A leak-resistant daily mug that keeps morning coffee warm on the move.",
            category: "Home", subcategory: "Kitchen", price: 32, rating: 4.8, reviews: 1_106,
            imageURL: "https://images.unsplash.com/photo-1514228742587-6b1558fcca3d?auto=format&fit=crop&w=1200&q=85",
            tags: ["practical", "budget-friendly", "coffee", "kitchen"], localImageName: "mug"
        ),
        Product(
            id: "throw", name: "Softlight Knit Throw", brand: "Hearth & Form",
            description: "A breathable cotton layer with a cozy texture for slower evenings.",
            category: "Home", subcategory: "Textiles", price: 68, rating: 4.7, reviews: 386,
            imageURL: "https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?auto=format&fit=crop&w=1200&q=85",
            tags: ["aesthetic", "neutral", "cozy", "home"], localImageName: "throw"
        ),
    ]
}

struct FriendAccount: Codable, Identifiable, Hashable {
    let userId: String
    let username: String
    let relationship: String?

    var id: String { userId }
}

struct FriendShare: Codable, Identifiable, Hashable {
    let id: String
    let asin: String?
    let senderUsername: String
    let title: String
    let brand: String?
    let priceCents: Int?
    let imageUrl: String?
    let productUrl: String?
}

struct FriendData: Codable {
    var friends: [FriendAccount] = []
    var incomingRequests: [FriendAccount] = []
    var outgoingRequests: [FriendAccount] = []
    var shares: [FriendShare] = []
}

private struct CatalogEnvelope: Decodable {
    let products: [Product]
}

private struct ProductKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int? = nil
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
}

private extension KeyedDecodingContainer where Key == ProductKey {
    func string(_ keys: String...) -> String? {
        for key in keys {
            let codingKey = ProductKey(key)
            if let value = try? decode(String.self, forKey: codingKey), !value.isEmpty { return value }
            if let value = try? decode(Int.self, forKey: codingKey) { return String(value) }
        }
        return nil
    }

    func number(_ keys: String...) -> Double? {
        for key in keys {
            let codingKey = ProductKey(key)
            if let value = try? decode(Double.self, forKey: codingKey) { return value }
            if let value = try? decode(String.self, forKey: codingKey), let number = Double(value) { return number }
        }
        return nil
    }

    func strings(_ key: String) -> [String] {
        let codingKey = ProductKey(key)
        if let values = try? decode([String].self, forKey: codingKey) { return values }
        if let text = try? decode(String.self, forKey: codingKey) {
            if let data = text.data(using: .utf8),
               let values = try? JSONDecoder().decode([String].self, from: data) { return values }
            return text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        return []
    }
}

struct ShopCollection: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var productIDs: [String]
    let createdAt: Date

    init(id: String = UUID().uuidString, name: String, productIDs: [String] = [], createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.productIDs = productIDs
        self.createdAt = createdAt
    }
}

enum ShopSort: String, CaseIterable, Codable, Identifiable {
    case recommended
    case priceLowToHigh
    case priceHighToLow
    case topRated

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended: "For you"
        case .priceLowToHigh: "Price: low to high"
        case .priceHighToLow: "Price: high to low"
        case .topRated: "Top rated"
        }
    }
}

enum ShopAction: String, Codable, Hashable {
    case like, unlike, save, unsave, skip
    case tooExpensive = "too_expensive"
    case lessCategory = "less_category"
    case addToCart = "add_to_cart"
    case removeFromCart = "remove_from_cart"
}

struct ShopHistoryEvent: Identifiable, Codable, Hashable {
    let id: String
    let productID: String
    let action: ShopAction
    let createdAt: Date
    let dwellMilliseconds: Int?

    init(productID: String, action: ShopAction, dwellMilliseconds: Int? = nil) {
        id = UUID().uuidString
        self.productID = productID
        self.action = action
        createdAt = .now
        self.dwellMilliseconds = dwellMilliseconds
    }
}

struct ShopFeedback: Identifiable, Codable, Hashable {
    let id: String
    let productID: String
    let category: String
    let action: ShopAction
    let createdAt: Date

    init(productID: String, category: String, action: ShopAction) {
        id = UUID().uuidString
        self.productID = productID
        self.category = category
        self.action = action
        createdAt = .now
    }
}
