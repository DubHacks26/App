import SwiftUI

struct ProductDetailsView: View {
    let product: Product
    @ObservedObject var store: ShopStore
    let onSave: () -> Void
    let onFeedback: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ProductArtwork(product: product)
                    .frame(height: 320)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(ShopTheme.ink)
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.95), in: Circle())
                        }
                        .accessibilityLabel("Close details")
                        .padding(16)
                    }

                VStack(alignment: .leading, spacing: 16) {
                    SectionKicker(title: product.brand)
                    Text(product.name)
                        .font(ShopTheme.display(38))
                        .foregroundStyle(ShopTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text(product.formattedPrice)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(ShopTheme.ink)
                        Spacer()
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color(red: 0.92, green: 0.66, blue: 0.35))
                        Text("\(product.rating.formatted(.number.precision(.fractionLength(1)))) · \(product.reviews.formatted()) ratings")
                            .font(.system(size: 13))
                            .foregroundStyle(ShopTheme.muted)
                    }

                    Text(product.description)
                        .font(.system(size: 15))
                        .foregroundStyle(ShopTheme.muted)
                        .lineSpacing(5)
                        .padding(.vertical, 4)

                    HStack(spacing: 9) {
                        Button(action: onSave) {
                            Label(store.isSaved(product.id) ? "Edit collections" : "Save to collection", systemImage: "bookmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PlumButtonStyle())

                        Button {
                            store.addToCart(product)
                            onFeedback("\(product.name) added to your cart")
                        } label: {
                            Label(store.isInCart(product.id) ? "In cart" : "Add to cart", systemImage: "bag")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PlumButtonStyle(secondary: true))
                        .disabled(store.isInCart(product.id))
                    }

                    ShareLink(item: shareText) {
                        Label("Share this find", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ShopTheme.plum)
                    }
                    .padding(.top, 4)

                    Divider().padding(.vertical, 5)
                    SectionKicker(title: "Category & tags")
                    metadataRow("Category", value: product.category)
                    if let subcategory = product.subcategory {
                        metadataRow("Subcategory", value: subcategory)
                    }
                    if !product.tags.isEmpty {
                        FlowTags(tags: product.tags)
                    }

                    SectionKicker(title: "About this find")
                        .padding(.top, 12)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(ShopTheme.plum)
                        Text("Heart or save this product to keep track of what catches your eye.")
                            .font(.system(size: 14))
                            .foregroundStyle(ShopTheme.muted)
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))

                    if let retailerURL = product.productURL.flatMap(URL.init(string:)), retailerURL.scheme == "https" {
                        Link(destination: retailerURL) {
                            Label("Visit retailer", systemImage: "arrow.up.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PlumButtonStyle(secondary: true))
                        .padding(.top, 5)
                    }

                    SectionKicker(title: "Tune your feed")
                        .padding(.top, 15)
                    Button {
                        store.recordTooExpensive(product)
                        onFeedback("We’ll prioritize lower-priced finds")
                        dismiss()
                    } label: {
                        feedbackRow("Too expensive", subtitle: "Prioritize lower-priced finds", symbol: "tag")
                    }
                    Button {
                        store.recordLessOfCategory(product)
                        onFeedback("We’ll show fewer \(product.category) finds")
                        dismiss()
                    } label: {
                        feedbackRow("Show less like this", subtitle: "Fewer \(product.category) finds", symbol: "hand.thumbsdown")
                    }
                }
                .padding(20)
            }
        }
        .background(ShopTheme.paper)
        .ignoresSafeArea(edges: .top)
    }

    private var shareText: String {
        guard let url = product.productURL else { return "Found \(product.name) on ShopScroll" }
        return "Found \(product.name) on ShopScroll: \(url)"
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(ShopTheme.muted)
            Spacer()
            Text(value).fontWeight(.semibold).foregroundStyle(ShopTheme.ink)
        }
        .font(.system(size: 14))
        .padding(.vertical, 4)
    }

    private func feedbackRow(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(ShopTheme.plum)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.semibold).foregroundStyle(ShopTheme.ink)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(ShopTheme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(ShopTheme.muted)
        }
        .font(.system(size: 14))
        .padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct FlowTags: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag.replacingOccurrences(of: "#", with: ""))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ShopTheme.plum)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(ShopTheme.lavender, in: Capsule())
                }
            }
        }
        .scrollClipDisabled()
    }
}
