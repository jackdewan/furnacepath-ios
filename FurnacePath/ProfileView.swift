import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var pairingCode: String?
    @State private var pairingLoading = false
    @State private var pairingError = false
    @State private var serverReachable: Bool?

    private var userInfo: UserInfo? { UserInfo.load() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if store.isDemo { demoBanner }
                identityCard
                statsRow
                if store.isDemo {
                    exitDemoSection
                    ownerOnlySection
                } else if store.authState == .signedIn && API.sessionToken != nil {
                    pairingSection
                    serverCard
                    signOutSection
                    footer
                }
            }
            .padding(20)
            .frame(maxWidth: 700)
        }
        .background(Color.paper)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if !store.isDemo { await fetchPairingCode() }
            await checkServer()
        }
    }

    // MARK: - Demo banner
    private var demoBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "eye")
                .font(.title3)
                .foregroundStyle(Color.orangeAccent)
            VStack(alignment: .leading, spacing: 4) {
                Text("You are in the demo").font(.subheadline.bold())
                Text("Sample data only. Nothing here touches the owner's real progress, and this data resets on its own.")
                    .font(.caption)
                    .foregroundStyle(Color.ink.opacity(0.6))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Identity card
    private var identityCard: some View {
        HStack(spacing: 14) {
            if store.isDemo {
                Image(systemName: "person.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.ink.opacity(0.3))
            } else {
                let initials = initialsFromName(userInfo?.name)
                Text(initials)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.ink, in: Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                if store.isDemo {
                    HStack(spacing: 6) {
                        Text("Demo account").font(.headline)
                        Text("DEMO").font(.caption2.bold())
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.ink.opacity(0.08), in: Capsule())
                    }
                    Text("No sign-in. This session ends on its own.")
                        .font(.caption).foregroundStyle(Color.ink.opacity(0.55))
                } else if store.authState == .signedIn && API.sessionToken != nil {
                    Text(userInfo?.name ?? "Signed in").font(.headline)
                    Text("Signed in with Apple")
                        .font(.caption).foregroundStyle(Color.ink.opacity(0.55))
                    if let email = userInfo?.email {
                        Text(maskedEmail(email))
                            .font(.caption).foregroundStyle(Color.ink.opacity(0.4))
                    }
                } else { Text("Signed out").font(.headline) }
            }
            Spacer()
            if store.authState == .signedIn && API.sessionToken != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.steel)
                    .font(.title3)
            }
        }
        .padding(16)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stats row
    private var statsRow: some View {
        let s = store.state
        let isDemo = store.isDemo
        let sub = isDemo ? "sample data" : nil
        return HStack(spacing: 0) {
            statColumn("XP", "\(s?.xp ?? 0)", sub ?? "total earned")
            Divider().frame(height: 50)
            statColumn("STREAK", "\(s?.streak ?? 0) day\(s?.streak == 1 ? "" : "s")", sub ?? "keep it alive")
            Divider().frame(height: 50)
            statColumn("PATH", "Unit \(s?.currentUnit ?? 1)",
                        sub ?? "\(s?.units.first?.lessonsCompleted ?? 0) of 8 lessons")
        }
        .padding(.vertical, 14)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
    }

    private func statColumn(_ label: String, _ value: String, _ caption: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2.bold()).foregroundStyle(Color.ink.opacity(0.5))
            Text(value).font(.title3.bold())
            Text(caption).font(.caption2).foregroundStyle(Color.ink.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Pairing section (real users only)
    private var pairingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PAIR THE WEB APP")
                .font(.caption.bold())
                .foregroundStyle(Color.orangeAccent)

            if let code = pairingCode {
                HStack(spacing: 8) {
                    ForEach(Array(code.enumerated()), id: \.offset) { _, digit in
                        Text(String(digit))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .frame(width: 46, height: 56)
                            .background(Color.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else if pairingLoading {
                ProgressView().frame(height: 56)
            } else if pairingError {
                Text("Couldn't generate a code.").foregroundStyle(Color.ink.opacity(0.5))
            }

            Text("Enter this code in the web app on your computer. It ")
                + Text("expires in 10 minutes").bold()
                + Text(", works once, and a new code kills this one.")

            Button {
                Task { await fetchPairingCode() }
            } label: {
                Text("Generate new code")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(pairingLoading)
        }
        .padding(16)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Server status card
    private var serverCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(serverReachable == true ? Color.steel : Color.ink.opacity(0.2))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text("Shop server · P51").font(.subheadline.bold())
                Text("Your data lives on your own server, nowhere else.")
                    .font(.caption).foregroundStyle(Color.ink.opacity(0.55))
            }
            Spacer()
            if let reachable = serverReachable {
                Text(reachable ? "Connected" : "Offline")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(reachable ? Color.steel : Color.ink.opacity(0.4))
            }
        }
        .padding(16)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Sign out (real users)
    private var signOutSection: some View {
        Button {
            store.signOut()
            dismiss()
        } label: {
            Text("Sign out")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.orangeAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var footer: some View {
        Text("FurnacePath 1.0 · Only a sign-in token is stored.")
            .font(.caption)
            .foregroundStyle(Color.ink.opacity(0.4))
            .frame(maxWidth: .infinity)
    }

    // MARK: - Demo sections
    private var exitDemoSection: some View {
        VStack(spacing: 10) {
            Button {
                store.signOut()
                dismiss()
            } label: {
                Text("Exit demo")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Text("Exiting clears everything from this session\nand returns to the sign-in screen.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.ink.opacity(0.5))
        }
    }

    private var ownerOnlySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("OWNER ONLY")
                .font(.caption.bold())
                .foregroundStyle(Color.ink.opacity(0.5))
                .padding(.bottom, 12)
            ownerRow("Pair the web app")
            Divider()
            ownerRow("Claim server progress")
            Divider()
            ownerRow("Sign out")
        }
        .padding(.top, 8)
    }

    private func ownerRow(_ label: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.ink.opacity(0.35))
            Spacer()
            Text("Hidden in demo").font(.caption).foregroundStyle(Color.ink.opacity(0.3))
        }
        .padding(.vertical, 12)
    }

    // MARK: - Helpers
    private func fetchPairingCode() async {
        pairingLoading = true; pairingError = false
        do {
            let result = try await store.generatePairingCode()
            pairingCode = result.code
        } catch { pairingError = true }
        pairingLoading = false
    }

    private func checkServer() async {
        do {
            let _: ProgressState = try await API.request("api/state")
            serverReachable = true
        } catch {
            serverReachable = !(error is APIError) ? false : true
        }
    }

    private func initialsFromName(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 { return (String(parts[0].prefix(1)) + String(parts[1].prefix(1))).uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    private func maskedEmail(_ email: String) -> String {
        guard let at = email.firstIndex(of: "@") else { return email }
        let local = email[email.startIndex..<at]
        let domain = email[at...]
        if local.count <= 1 { return email }
        return String(local.prefix(1)) + String(repeating: "•", count: min(local.count - 1, 5)) + String(domain)
    }
}
