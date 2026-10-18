import SwiftUI

enum ShopTheme {
    static let ink = Color(red: 42 / 255, green: 32 / 255, blue: 40 / 255)
    static let muted = Color(red: 119 / 255, green: 109 / 255, blue: 115 / 255)
    static let paper = Color(red: 248 / 255, green: 246 / 255, blue: 242 / 255)
    static let plum = Color(red: 109 / 255, green: 58 / 255, blue: 99 / 255)
    static let lavender = Color(red: 233 / 255, green: 222 / 255, blue: 235 / 255)
    static let coral = Color(red: 227 / 255, green: 111 / 255, blue: 94 / 255)
    static let line = Color(red: 231 / 255, green: 225 / 255, blue: 220 / 255)
    static let sage = Color(red: 223 / 255, green: 232 / 255, blue: 221 / 255)

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
}

struct ProductArtwork: View {
    let product: Product
    var fit = false

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let name = product.localImageName {
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: fit ? .fit : .fill)
                } else if let url = URL(string: product.imageURL), url.scheme == "https" {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: fit ? .fit : .fill)
                        } else {
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .accessibilityLabel(product.name)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [ShopTheme.lavender, ShopTheme.plum.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "bag")
                .font(.system(size: 50, weight: .ultraLight))
                .foregroundStyle(ShopTheme.plum.opacity(0.65))
        }
    }
}

struct SectionKicker: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(2.3)
            .foregroundStyle(ShopTheme.plum)
    }
}

struct PlumButtonStyle: ButtonStyle {
    var secondary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(secondary ? ShopTheme.plum : .white)
            .padding(.horizontal, 20)
            .frame(minHeight: 48)
            .background(secondary ? ShopTheme.lavender : ShopTheme.plum, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(ShopTheme.plum)
                .frame(width: 72, height: 72)
                .background(ShopTheme.lavender, in: RoundedRectangle(cornerRadius: 22))
            Text(title)
                .font(ShopTheme.display(30))
                .foregroundStyle(ShopTheme.ink)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(ShopTheme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ShopTheme.paper)
    }
}

struct ProductRow: View {
    let product: Product
    var accessory: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ProductArtwork(product: product)
                    .frame(width: 78, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Text(product.brand.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.3)
                        .foregroundStyle(ShopTheme.plum)
                    Text(product.name)
                        .font(ShopTheme.display(19))
                        .foregroundStyle(ShopTheme.ink)
                        .lineLimit(2)
                    Text(product.formattedPrice)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ShopTheme.muted)
                }
                Spacer(minLength: 4)
                if let accessory {
                    Image(systemName: accessory)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ShopTheme.plum)
                }
            }
            .padding(10)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(ShopTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
