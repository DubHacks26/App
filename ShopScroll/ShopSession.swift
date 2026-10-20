import Foundation
import Security

private struct ServiceConfig {
    let backendURL: String
    let supabaseURL: String
    let publishableKey: String

    static let current: ServiceConfig = {
        guard let url = Bundle.main.url(forResource: "ServiceConfig", withExtension: "plist"),
              let values = NSDictionary(contentsOf: url) as? [String: String] else {
            return ServiceConfig(backendURL: "https://dubhacks26-production.up.railway.app", supabaseURL: "", publishableKey: "")
        }
        return ServiceConfig(
            backendURL: values["BackendURL"] ?? "https://dubhacks26-production.up.railway.app",
            supabaseURL: values["SupabaseURL"] ?? "",
            publishableKey: values["SupabasePublishableKey"] ?? ""
        )
    }()
}

private struct AuthUser: Codable {
    let id: String
    let email: String?
    let user_metadata: Metadata?

    struct Metadata: Codable {
        let username: String?
        let name: String?
    }

    var displayName: String { user_metadata?.username ?? user_metadata?.name ?? email ?? "Shopper" }
}

private struct AuthSessionPayload: Codable {
    let access_token: String
    let refresh_token: String
    let expires_at: TimeInterval?
    let expires_in: TimeInterval?
    let user: AuthUser?
}

private struct AuthResponse: Decodable {
    let user: AuthUser?
    let session: AuthSessionPayload?
}

private struct StoredSession: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userID: String
    var displayName: String
}

private struct ServerError: Decodable {
    let error: Message?
    let message: String?

    struct Message: Decodable {
        let text: String

        init(from decoder: Decoder) throws {
            if let value = try? decoder.singleValueContainer().decode(String.self) {
                text = value
                return
            }
            let object = try decoder.container(keyedBy: CodingKeys.self)
            text = try object.decodeIfPresent(String.self, forKey: .reason)
                ?? object.decodeIfPresent(String.self, forKey: .message)
                ?? "The server could not complete the request."
        }

        private enum CodingKeys: String, CodingKey { case reason, message }
    }
}

enum ShopServiceError: LocalizedError {
    case invalidURL
    case notSignedIn
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Enter a valid server URL."
        case .notSignedIn: "Please sign in to load products."
        case .server(let message): message
        }
    }
}

@MainActor
final class ShopSession: ObservableObject {
    @Published private(set) var signedIn = false
    @Published private(set) var restoring = true
    @Published private(set) var loadingProducts = false
    @Published private(set) var catalogReady = false
    @Published private(set) var displayName = "Shopper"
    @Published private(set) var userID: String?
    @Published var errorMessage: String?
    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: Self.serverURLKey) }
    }

    private static let serverURLKey = "shopscroll.serverURL"
    private static let previousDefaultServerURL = "http://localhost:8000"
    private static let keychainService = "com.cameron.ShopScroll.session"
    private var credentials: StoredSession?
    private var recommendationRefreshTask: Task<Void, Never>?

    init() {
        let savedURL = UserDefaults.standard.string(forKey: Self.serverURLKey)
        serverURL = savedURL == Self.previousDefaultServerURL
            ? ServiceConfig.current.backendURL
            : (savedURL ?? ServiceConfig.current.backendURL)
        credentials = Self.readKeychain()
        if let credentials {
            userID = credentials.userID
            displayName = credentials.displayName
            signedIn = true
        }
    }

    func restore(into store: ShopStore) async {
        defer { restoring = false }
        guard let credentials else { return }
        store.configureAccount(credentials.userID)
        do { try await loadProducts(into: store) }
        catch { errorMessage = error.localizedDescription }
    }

    func signIn(identifier: String, password: String, into store: ShopStore) async throws {
        let body = ["identifier": identifier.trimmingCharacters(in: .whitespacesAndNewlines), "password": password]
        let data = try await request(path: "/auth/signin", method: "POST", json: body, authenticated: false)
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)
        guard let payload = response.session, let user = response.user ?? payload.user else {
            throw ShopServiceError.server("Sign-in succeeded, but no session was returned.")
        }
        accept(payload, user: user)
        store.configureAccount(user.id)
        try await loadProducts(into: store)
    }

    /// Returns false when the account was created but email confirmation is required.
    func signUp(username: String, email: String, password: String, into store: ShopStore) async throws -> Bool {
        let body = ["username": username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                    "email": email.trimmingCharacters(in: .whitespacesAndNewlines), "password": password]
        let data = try await request(path: "/auth/signup", method: "POST", json: body, authenticated: false)
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)
        guard let payload = response.session, let user = response.user ?? payload.user else { return false }
        accept(payload, user: user)
        store.configureAccount(user.id)
        try await loadProducts(into: store)
        return true
    }

    func signOut() {
        recommendationRefreshTask?.cancel()
        recommendationRefreshTask = nil
        credentials = nil
        Self.deleteKeychain()
        signedIn = false
        displayName = "Shopper"
        userID = nil
        catalogReady = false
        errorMessage = nil
    }

    func loadProducts(into store: ShopStore) async throws {
        loadingProducts = true
        defer { loadingProducts = false }
        do {
            let catalogData = try await request(path: "/user/catalog", query: ["limit": "100"])
            let catalog = try Product.decodeCatalog(from: catalogData)
            guard !catalog.isEmpty else { throw ShopServiceError.server("The server catalog is empty.") }

            // Recommendations provide the order; catalog rows fill any missing fields.
            let recommendedData = try? await request(path: "/user/recommendations", query: ["limit": "100"])
            let recommendations = recommendedData.flatMap { try? Product.decodeCatalog(from: $0) } ?? []
            store.replaceProducts(with: Self.orderedProducts(recommendations, followedBy: catalog))
            catalogReady = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func searchProducts(_ query: String) async throws -> [Product] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }
        let data = try await request(path: "/user/search", query: ["query": clean])
        let matches = try Product.decodeCatalog(from: data)
        let asins = matches.map(\.id).filter(Self.isASIN)
        guard !asins.isEmpty else { return [] }
        let detailData = try await request(path: "/user/history-products", query: ["asins": asins.joined(separator: ",")])
        let details = try Product.decodeCatalog(from: detailData)
        let byID = Dictionary(uniqueKeysWithValues: details.map { ($0.id, $0) })
        return asins.compactMap { byID[$0] }
    }

    func loadFriendData() async throws -> FriendData {
        let data = try await request(path: "/user/friends")
        return try JSONDecoder().decode(FriendData.self, from: data)
    }

    func searchFriendAccounts(_ query: String) async throws -> [FriendAccount] {
        let data = try await request(path: "/user/friends/search", query: ["query": query])
        struct Results: Decodable { let users: [FriendAccount] }
        return try JSONDecoder().decode(Results.self, from: data).users
    }

    func sendFriendRequest(to friendID: String) async throws {
        _ = try await request(path: "/user/friends/requests", method: "POST", json: ["friendId": friendID])
    }

    func respondToFriendRequest(from friendID: String, accept: Bool) async throws {
        _ = try await request(path: "/user/friends/requests", method: "PATCH", json: ["friendId": friendID, "accept": accept])
    }

    func removeFriend(_ friendID: String) async throws {
        let encodedID = friendID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? friendID
        _ = try await request(path: "/user/friends/\(encodedID)", method: "DELETE")
    }

    func shareProduct(_ productID: String, with friendID: String) async throws {
        _ = try await request(path: "/user/friends/shares", method: "POST", json: ["friendId": friendID, "asin": productID])
    }

    func submitSearch(_ query: String, into store: ShopStore) async {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        do {
            _ = try await request(path: "/user/search", method: "POST", json: ["query": clean])
            scheduleRecommendationRefresh(into: store)
        } catch {
            errorMessage = "Search feedback could not sync: \(error.localizedDescription)"
        }
    }

    func persist(_ event: ShopHistoryEvent, into store: ShopStore) async {
        guard Self.isASIN(event.productID), let userID else { return }
        let action = event.action.rawValue
        guard ["like", "unlike", "save", "unsave", "skip", "too_expensive", "less_category"].contains(action) else { return }
        do {
            let row: [String: Any] = [
                "user_id": userID,
                "asin": event.productID,
                "action": action,
                "dwell_ms": event.dwellMilliseconds as Any? ?? NSNull()
            ]
            _ = try await supabaseRequest(path: "/rest/v1/product_interactions", method: "POST", json: row)
            if ["like", "save", "skip", "too_expensive", "less_category"].contains(action) {
                var payload: [String: Any] = ["asin": event.productID, "action": action]
                if action == "skip", let dwell = event.dwellMilliseconds { payload["dwellMs"] = min(dwell, 3_600_000) }
                _ = try await request(path: "/user/interactions", method: "POST", json: payload)
                scheduleRecommendationRefresh(into: store)
            }
            errorMessage = nil
        } catch {
            errorMessage = "Your action stayed on this device, but could not sync: \(error.localizedDescription)"
        }
    }

    private func scheduleRecommendationRefresh(into store: ShopStore) {
        recommendationRefreshTask?.cancel()
        recommendationRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, let self else { return }
            do {
                let data = try await self.request(path: "/user/recommendations", query: ["limit": "100"])
                guard !Task.isCancelled else { return }
                let recommendations = try Product.decodeCatalog(from: data)
                guard !recommendations.isEmpty else { return }
                store.replaceProducts(with: Self.orderedProducts(recommendations, followedBy: store.products))
            } catch {
                // The current catalog stays usable when a recommendation refresh fails.
            }
        }
    }

    private static func orderedProducts(_ recommendations: [Product], followedBy catalog: [Product]) -> [Product] {
        let byID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        var seen = Set<String>()
        return (recommendations.map { byID[$0.id] ?? $0 } + catalog)
            .filter { seen.insert($0.id).inserted }
    }

    private func accept(_ payload: AuthSessionPayload, user: AuthUser) {
        let expires = payload.expires_at.map { Date(timeIntervalSince1970: $0) }
            ?? Date.now.addingTimeInterval(payload.expires_in ?? 3600)
        credentials = StoredSession(
            accessToken: payload.access_token,
            refreshToken: payload.refresh_token,
            expiresAt: expires,
            userID: user.id,
            displayName: user.displayName
        )
        Self.writeKeychain(credentials!)
        userID = user.id
        displayName = user.displayName
        signedIn = true
        errorMessage = nil
    }

    private func validToken() async throws -> String {
        guard let credentials else { throw ShopServiceError.notSignedIn }
        if credentials.expiresAt.timeIntervalSinceNow < 60 { try await refreshToken() }
        guard let token = self.credentials?.accessToken else { throw ShopServiceError.notSignedIn }
        return token
    }

    private func refreshToken() async throws {
        guard let credentials else { throw ShopServiceError.notSignedIn }
        guard !ServiceConfig.current.supabaseURL.isEmpty,
              !ServiceConfig.current.publishableKey.isEmpty else {
            throw ShopServiceError.server("Supabase public configuration is missing.")
        }
        let data = try await supabaseRequest(
            path: "/auth/v1/token",
            method: "POST",
            query: ["grant_type": "refresh_token"],
            json: ["refresh_token": credentials.refreshToken],
            token: nil
        )
        let payload = try JSONDecoder().decode(AuthSessionPayload.self, from: data)
        let user = payload.user ?? AuthUser(id: credentials.userID, email: nil, user_metadata: nil)
        accept(payload, user: user)
    }

    private func request(
        path: String,
        method: String = "GET",
        query: [String: String] = [:],
        json: Any? = nil,
        authenticated: Bool = true
    ) async throws -> Data {
        guard let base = URL(string: serverURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(base.scheme?.lowercased() ?? "") else { throw ShopServiceError.invalidURL }
        let token = authenticated ? try await validToken() : nil
        return try await send(base: base, path: path, method: method, query: query, json: json, token: token, apiKey: nil)
    }

    private func supabaseRequest(
        path: String,
        method: String,
        query: [String: String] = [:],
        json: Any,
        token: String? = nil
    ) async throws -> Data {
        guard let base = URL(string: ServiceConfig.current.supabaseURL) else { throw ShopServiceError.invalidURL }
        var access = token
        if access == nil && !path.hasPrefix("/auth/") {
            access = try await validToken()
        }
        return try await send(base: base, path: path, method: method, query: query, json: json, token: access, apiKey: ServiceConfig.current.publishableKey)
    }

    private func send(
        base: URL,
        path: String,
        method: String,
        query: [String: String],
        json: Any?,
        token: String?,
        apiKey: String?
    ) async throws -> Data {
        guard var components = URLComponents(url: base.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw ShopServiceError.invalidURL
        }
        if !query.isEmpty { components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        guard let url = components.url else { throw ShopServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let apiKey { request.setValue(apiKey, forHTTPHeaderField: "apikey") }
        if let json {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw ShopServiceError.server("No HTTP response from the server.") }
        guard (200..<300).contains(response.statusCode) else {
            let parsed = try? JSONDecoder().decode(ServerError.self, from: data)
            if response.statusCode == 401 && path != "/auth/signin" && path != "/auth/signup" {
                throw ShopServiceError.server("Your session expired. Please sign in again.")
            }
            throw ShopServiceError.server(parsed?.error?.text ?? parsed?.message ?? "Server returned HTTP \(response.statusCode).")
        }
        return data
    }

    private static func isASIN(_ value: String) -> Bool {
        value.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) != nil
    }

    private static func readKeychain() -> StoredSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "session",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(StoredSession.self, from: data)
    }

    private static func writeKeychain(_ session: StoredSession) {
        deleteKeychain()
        guard let data = try? JSONEncoder().encode(session) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "session",
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func deleteKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "session"
        ]
        SecItemDelete(query as CFDictionary)
    }
}
