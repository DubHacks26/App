import SwiftUI

struct SignInView: View {
    @ObservedObject var session: ShopSession
    @ObservedObject var store: ShopStore

    @State private var creatingAccount = false
    @State private var identifier = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    @State private var notice: String?
    @State private var showServerSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("shop").foregroundStyle(ShopTheme.ink)
                    Text("scroll").foregroundStyle(ShopTheme.plum)
                }
                .font(ShopTheme.display(31))
                .padding(.top, 18)

                VStack(alignment: .leading, spacing: 10) {
                    SectionKicker(title: "A little scroll. A better find.")
                    Text("Your next \(Text("favorite").italic()) is waiting.")
                        .font(ShopTheme.display(43))
                        .foregroundStyle(ShopTheme.ink)
                    Text("A space for your taste, your wish list, and the finds that feel like you.")
                        .font(.system(size: 15))
                        .foregroundStyle(ShopTheme.muted)
                        .lineSpacing(4)
                    HStack(spacing: 8) {
                        Circle().fill(ShopTheme.plum)
                        Circle().fill(ShopTheme.coral)
                        Circle().fill(ShopTheme.sage)
                    }
                    .frame(width: 71, height: 17)
                }

                VStack(alignment: .leading, spacing: 17) {
                    SectionKicker(title: "Your taste. Your space.")
                    Text(creatingAccount ? "Join the scroll" : "Welcome back")
                        .font(ShopTheme.display(31))
                        .foregroundStyle(ShopTheme.ink)
                    Text(creatingAccount ? "Create your account to discover a feed made for you." : "Sign in to load products from your ShopScroll server.")
                        .font(.system(size: 14))
                        .foregroundStyle(ShopTheme.muted)

                    if creatingAccount {
                        field("Username", text: $username, hint: "your_username")
                            .textInputAutocapitalization(.never)
                        field("Email", text: $email, hint: "you@example.com")
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                    } else {
                        field("Username or email", text: $identifier, hint: "your_username or you@example.com")
                            .textInputAutocapitalization(.never)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ShopTheme.ink)
                        SecureField("Enter your password", text: $password)
                            .textContentType(creatingAccount ? .newPassword : .password)
                            .padding(.horizontal, 14)
                            .frame(height: 47)
                            .background(ShopTheme.paper, in: RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(ShopTheme.line))
                    }

                    if let error {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(ShopTheme.coral)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let notice {
                        Text(notice)
                            .font(.system(size: 12))
                            .foregroundStyle(ShopTheme.plum)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: submit) {
                        HStack {
                            Spacer()
                            if busy { ProgressView().tint(.white) }
                            Text(busy ? "Please wait…" : creatingAccount ? "Create account" : "Sign in")
                            Spacer()
                        }
                    }
                    .buttonStyle(PlumButtonStyle())
                    .disabled(busy || password.isEmpty)

                    HStack(spacing: 4) {
                        Text(creatingAccount ? "Already have an account?" : "New here?")
                            .foregroundStyle(ShopTheme.muted)
                        Button(creatingAccount ? "Sign in" : "Create an account") {
                            creatingAccount.toggle()
                            error = nil
                            notice = nil
                            password = ""
                        }
                        .foregroundStyle(ShopTheme.plum)
                        .fontWeight(.semibold)
                    }
                    .font(.system(size: 13))
                }
                .padding(21)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(ShopTheme.line))

                VStack(alignment: .leading, spacing: 9) {
                    Button {
                        withAnimation { showServerSettings.toggle() }
                    } label: {
                        Label("Server settings", systemImage: "server.rack")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ShopTheme.plum)
                    }
                    if showServerSettings {
                        TextField("Server URL", text: $session.serverURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .font(.system(size: 13))
                            .padding(12)
                            .background(.white, in: RoundedRectangle(cornerRadius: 11))
                        Text("The Railway server is the default. Change this only when testing another backend.")
                            .font(.system(size: 11))
                            .foregroundStyle(ShopTheme.muted)
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 21)
        }
        .background(ShopTheme.paper)
    }

    private func field(_ label: String, text: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ShopTheme.ink)
            TextField(hint, text: text)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 47)
                .background(ShopTheme.paper, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(ShopTheme.line))
        }
    }

    private func submit() {
        guard !busy else { return }
        busy = true
        error = nil
        notice = nil
        Task {
            do {
                if creatingAccount {
                    let signedIn = try await session.signUp(username: username, email: email, password: password, into: store)
                    if !signedIn {
                        creatingAccount = false
                        identifier = email
                        notice = "Account created. Confirm your email, then sign in."
                    }
                } else {
                    try await session.signIn(identifier: identifier, password: password, into: store)
                }
                password = ""
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}

struct ServerProblemView: View {
    @ObservedObject var session: ShopSession
    @ObservedObject var store: ShopStore

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 31))
                .foregroundStyle(ShopTheme.plum)
            Text("The catalog didn’t load")
                .font(ShopTheme.display(31))
                .foregroundStyle(ShopTheme.ink)
            Text(session.errorMessage ?? "Check the server and try again.")
                .font(.system(size: 14))
                .foregroundStyle(ShopTheme.muted)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { try? await session.loadProducts(into: store) }
            }
            .buttonStyle(PlumButtonStyle())
            Button("Sign out") { session.signOut() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ShopTheme.plum)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ShopTheme.paper)
    }
}
