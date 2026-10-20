import SwiftUI

struct FriendsView: View {
    @ObservedObject var session: ShopSession
    let onDetails: (Product) -> Void

    @State private var data = FriendData()
    @State private var query = ""
    @State private var results: [FriendAccount] = []
    @State private var loading = true
    @State private var searching = false
    @State private var busyID: String?
    @State private var error: String?
    @State private var notice: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    SectionKicker(title: "Shop together")
                    Text("Friends")
                        .font(ShopTheme.display(34))
                        .foregroundStyle(ShopTheme.ink)
                    Text("Find people by username, connect, and share products you think they’ll love.")
                        .font(.system(size: 14))
                        .foregroundStyle(ShopTheme.muted)
                        .lineSpacing(3)
                }
                .padding(.top, 18)

                if let error { messageRow(error, isError: true) }
                if let notice { messageRow(notice, isError: false) }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Find friends")
                        .font(ShopTheme.display(23))
                        .foregroundStyle(ShopTheme.ink)
                    HStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(ShopTheme.muted)
                            TextField("Search usernames", text: $query)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.search)
                                .onSubmit { Task { await search() } }
                                .onChange(of: query) { _, value in
                                    let clean = normalized(value)
                                    if clean != value { query = clean }
                                }
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 46)
                        .background(ShopTheme.paper, in: RoundedRectangle(cornerRadius: 12))

                        Button { Task { await search() } } label: {
                            if searching {
                                ProgressView().tint(.white)
                                    .frame(width: 48, height: 46)
                                    .background(ShopTheme.plum, in: RoundedRectangle(cornerRadius: 12))
                            } else {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 48, height: 46)
                                    .background(ShopTheme.plum, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .disabled(searching || query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                        .accessibilityLabel("Search usernames")
                    }

                    if !results.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(results) { person in
                                personRow(person) { searchAction(for: person) }
                                if person.id != results.last?.id { ShopTheme.line.frame(height: 1) }
                            }
                        }
                    } else if !searching && query.count >= 2 {
                        Text("No matching usernames found.")
                            .font(.system(size: 13))
                            .foregroundStyle(ShopTheme.muted)
                    }
                }
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(ShopTheme.line, lineWidth: 1))

                if loading {
                    ProgressView("Loading your friends…")
                        .tint(ShopTheme.plum)
                        .frame(maxWidth: .infinity, minHeight: 170)
                } else {
                    requestsSection
                    friendsSection
                    sharesSection
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .background(ShopTheme.paper)
        .refreshable { await refresh() }
        .task { await refresh() }
    }

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Friend requests", count: data.incomingRequests.count)
            if data.incomingRequests.isEmpty {
                emptyText("No pending requests.")
            } else {
                VStack(spacing: 0) {
                    ForEach(data.incomingRequests) { person in
                        personRow(person) {
                            HStack(spacing: 8) {
                                Button("Accept") {
                                    Task { await update(person, success: "You and @\(person.username) are now friends.") {
                                        try await session.respondToFriendRequest(from: person.userId, accept: true)
                                    } }
                                }
                                .buttonStyle(PlumButtonStyle())
                                Button {
                                    Task { await update(person, success: "Request from @\(person.username) declined.") {
                                        try await session.respondToFriendRequest(from: person.userId, accept: false)
                                    } }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(ShopTheme.muted)
                                        .frame(width: 40, height: 40)
                                        .background(ShopTheme.paper, in: Circle())
                                }
                                .accessibilityLabel("Decline request from @\(person.username)")
                                .disabled(busyID == person.id)
                            }
                        }
                    }
                }
            }

            if !data.outgoingRequests.isEmpty {
                Text("Sent")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ShopTheme.muted)
                    .padding(.top, 4)
                ForEach(data.outgoingRequests) { person in
                    personRow(person) {
                        Text("Request sent")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ShopTheme.muted)
                    }
                }
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(ShopTheme.line, lineWidth: 1))
    }

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Your friends", count: data.friends.count)
            if data.friends.isEmpty {
                emptyText("Search for a username to add your first friend.")
            } else {
                ForEach(data.friends) { person in
                    personRow(person) {
                        Button(role: .destructive) {
                            Task { await update(person, success: "@\(person.username) was removed from your friends.") {
                                try await session.removeFriend(person.userId)
                            } }
                        } label: {
                            if busyID == person.id {
                                ProgressView().tint(ShopTheme.plum)
                            } else {
                                Text("Remove")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(ShopTheme.plum)
                            }
                        }
                        .disabled(busyID == person.id)
                    }
                }
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(ShopTheme.line, lineWidth: 1))
    }

    private var sharesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Shared with you", count: data.shares.count)
            if data.shares.isEmpty {
                emptyText("Products your friends share with you will appear here.")
            } else {
                ForEach(data.shares) { share in
                    Button {
                        if let product = sessionProduct(for: share) { onDetails(product) }
                    } label: {
                        HStack(spacing: 12) {
                            AsyncImage(url: share.imageUrl.flatMap(URL.init(string:))) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ShopTheme.lavender.overlay {
                                    Image(systemName: "bag")
                                        .foregroundStyle(ShopTheme.plum)
                                }
                            }
                            .frame(width: 70, height: 78)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("@\(share.senderUsername) shared")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(ShopTheme.plum)
                                Text(share.title)
                                    .font(ShopTheme.display(18))
                                    .foregroundStyle(ShopTheme.ink)
                                    .lineLimit(2)
                                if let brand = share.brand, !brand.isEmpty {
                                    Text(brand)
                                        .font(.system(size: 12))
                                        .foregroundStyle(ShopTheme.muted)
                                }
                                if let cents = share.priceCents {
                                    Text((Double(cents) / 100).formatted(.currency(code: "USD")))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(ShopTheme.ink)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ShopTheme.plum)
                        }
                        .padding(9)
                        .background(ShopTheme.paper, in: RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(ShopTheme.line, lineWidth: 1))
    }

    private func searchAction(for person: FriendAccount) -> some View {
        Group {
            switch person.relationship ?? "" {
            case "friends":
                Text("Friends")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ShopTheme.muted)
            case "outgoing":
                Text("Request sent")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ShopTheme.muted)
            case "incoming":
                Button("Accept") {
                    Task { await update(person, success: "You and @\(person.username) are now friends.") {
                        try await session.respondToFriendRequest(from: person.userId, accept: true)
                    } }
                }
                .buttonStyle(PlumButtonStyle())
                .disabled(busyID == person.id)
            default:
                Button {
                    Task { await update(person, success: "Friend request sent to @\(person.username).") {
                        try await session.sendFriendRequest(to: person.userId)
                    } }
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ShopTheme.plum)
                }
                .disabled(busyID == person.id)
            }
        }
    }

    private func personRow<Accessory: View>(
        _ person: FriendAccount,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: 10) {
            Text(String(person.username.prefix(2)).uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ShopTheme.plum)
                .frame(width: 38, height: 38)
                .background(ShopTheme.lavender, in: Circle())
            Text("@\(person.username)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ShopTheme.ink)
                .lineLimit(1)
            Spacer(minLength: 4)
            accessory()
        }
        .padding(.vertical, 6)
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(ShopTheme.display(22))
                .foregroundStyle(ShopTheme.ink)
            Spacer()
            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(ShopTheme.plum)
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(ShopTheme.muted)
            .padding(.vertical, 5)
    }

    private func messageRow(_ text: String, isError: Bool) -> some View {
        Label(text, systemImage: isError ? "exclamationmark.circle" : "checkmark.circle")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isError ? ShopTheme.coral : ShopTheme.plum)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
    }

    private func normalized(_ value: String) -> String {
        String(value.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }.prefix(24))
    }

    private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else {
            error = "Enter at least two characters to search usernames."
            return
        }
        searching = true
        error = nil
        notice = nil
        do {
            results = try await session.searchFriendAccounts(term)
        } catch {
            self.error = error.localizedDescription
            results = []
        }
        searching = false
    }

    private func refresh() async {
        loading = true
        do {
            data = try await session.loadFriendData()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func update(
        _ person: FriendAccount,
        success: String,
        operation: () async throws -> Void
    ) async {
        busyID = person.id
        error = nil
        notice = nil
        do {
            try await operation()
            try await refreshData()
            if query.count >= 2 { results = try await session.searchFriendAccounts(query) }
            notice = success
        } catch {
            self.error = error.localizedDescription
        }
        busyID = nil
    }

    private func refreshData() async throws {
        data = try await session.loadFriendData()
    }

    private func sessionProduct(for share: FriendShare) -> Product? {
        guard let asin = share.asin else { return nil }
        return Product(
            id: asin,
            name: share.title,
            brand: share.brand ?? "Shared by @\(share.senderUsername)",
            description: share.title,
            category: "Shared",
            price: Double(share.priceCents ?? 0) / 100,
            rating: 0,
            reviews: 0,
            imageURL: share.imageUrl ?? "",
            productURL: share.productUrl
        )
    }
}

struct FriendShareView: View {
    let product: Product
    @ObservedObject var session: ShopSession
    let onFeedback: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var friends: [FriendAccount] = []
    @State private var loading = true
    @State private var busyID: String?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionKicker(title: "Share a find")
            Text("Send to a friend")
                .font(ShopTheme.display(29))
                .foregroundStyle(ShopTheme.ink)
            HStack(spacing: 12) {
                ProductArtwork(product: product)
                    .frame(width: 58, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ShopTheme.ink)
                        .lineLimit(2)
                    Text(product.formattedPrice)
                        .font(.system(size: 12))
                        .foregroundStyle(ShopTheme.muted)
                }
                Spacer()
            }
            if !isShareable {
                Text("This product is not available in the catalog to share.")
                    .font(.system(size: 12))
                    .foregroundStyle(ShopTheme.coral)
            }
            if let error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(ShopTheme.coral)
            }
            if loading {
                ProgressView("Loading your friends…")
                    .tint(ShopTheme.plum)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if friends.isEmpty {
                EmptyState(icon: "person.2", title: "No friends yet", message: "Add a friend before sharing a find.")
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(friends) { friend in
                            HStack(spacing: 10) {
                                Text(String(friend.username.prefix(2)).uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(ShopTheme.plum)
                                    .frame(width: 38, height: 38)
                                    .background(ShopTheme.lavender, in: Circle())
                                Text("@\(friend.username)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(ShopTheme.ink)
                                Spacer()
                                Button {
                                    Task { await share(with: friend) }
                                } label: {
                                    if busyID == friend.id {
                                        ProgressView().tint(.white)
                                            .frame(width: 72, height: 40)
                                            .background(ShopTheme.plum, in: RoundedRectangle(cornerRadius: 12))
                                    } else {
                                        Text("Send")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .frame(width: 72, height: 40)
                                            .background(ShopTheme.plum, in: RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                                .disabled(busyID != nil || !isShareable)
                            }
                            .padding(.vertical, 7)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ShopTheme.paper)
        .task { await loadFriends() }
    }

    private var isShareable: Bool {
        product.id.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) != nil
    }

    private func loadFriends() async {
        do {
            friends = try await session.loadFriendData().friends
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func share(with friend: FriendAccount) async {
        guard isShareable else {
            error = "This product is not available in the catalog to share."
            return
        }
        busyID = friend.id
        error = nil
        do {
            try await session.shareProduct(product.id, with: friend.userId)
            onFeedback("Shared with @\(friend.username)")
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        busyID = nil
    }
}