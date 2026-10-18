import SwiftUI

struct CollectionPickerView: View {
    let product: Product
    @ObservedObject var store: ShopStore
    let onUpdate: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var newName = ""
    @State private var initialized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    SectionKicker(title: "Save a favorite")
                    Text("Choose collections")
                        .font(ShopTheme.display(31))
                        .foregroundStyle(ShopTheme.ink)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ShopTheme.ink)
                        .frame(width: 36, height: 36)
                        .background(.white, in: Circle())
                }
                .accessibilityLabel("Close collection picker")
            }

            HStack(spacing: 12) {
                ProductArtwork(product: product)
                    .frame(width: 55, height: 55)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ShopTheme.ink)
                    Text(product.brand)
                        .font(.system(size: 12))
                        .foregroundStyle(ShopTheme.muted)
                }
                Spacer()
            }
            .padding(9)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))

            ScrollView {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: store.isLiked(product.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(store.isLiked(product.id) ? ShopTheme.coral : ShopTheme.muted)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Liked").fontWeight(.semibold)
                            Text("Added automatically when you heart a product")
                                .font(.system(size: 11))
                                .foregroundStyle(ShopTheme.muted)
                        }
                        Spacer()
                        Image(systemName: "heart.fill").foregroundStyle(ShopTheme.coral)
                    }
                    .font(.system(size: 14))
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 13))

                    ForEach(store.collections) { collection in
                        Button { toggle(collection.id) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selected.contains(collection.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(collection.id) ? ShopTheme.plum : ShopTheme.muted)
                                    .font(.system(size: 19))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(collection.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(ShopTheme.ink)
                                    Text("\(collection.productIDs.count) items")
                                        .font(.system(size: 11))
                                        .foregroundStyle(ShopTheme.muted)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(.white, in: RoundedRectangle(cornerRadius: 13))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 9) {
                TextField("Create a new collection", text: $newName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit(create)
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                Button("Create", action: create)
                    .buttonStyle(PlumButtonStyle(secondary: true))
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Button(action: apply) {
                Text(selected.isEmpty ? "Remove from collections" : "Save to \(selected.count) \(selected.count == 1 ? "collection" : "collections")")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlumButtonStyle())
        }
        .padding(19)
        .background(ShopTheme.paper)
        .onAppear {
            guard !initialized else { return }
            selected = Set(store.collections.filter { $0.productIDs.contains(product.id) }.map(\.id))
            initialized = true
        }
    }

    private func toggle(_ collectionID: String) {
        if selected.contains(collectionID) { selected.remove(collectionID) }
        else { selected.insert(collectionID) }
    }

    private func create() {
        guard let collection = store.createCollection(named: newName) else { return }
        selected.insert(collection.id)
        newName = ""
    }

    private func apply() {
        for collection in store.collections {
            let currentlySaved = collection.productIDs.contains(product.id)
            if currentlySaved != selected.contains(collection.id) {
                store.toggleSaved(product, in: collection.id)
            }
        }
        onUpdate(selected.isEmpty ? "Removed from collections" : "\(product.name) saved")
        dismiss()
    }
}
