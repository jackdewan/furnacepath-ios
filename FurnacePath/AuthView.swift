import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var store: Store
    @State private var showClaim = false
    @State private var claimData: ClaimResponse?
    @State private var signingIn = false
    @State private var signInError: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)

            // App icon
            Image(systemName: "flame.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text("FurnacePath")
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.5)
                .padding(.top, 16)

            Text("Learn the business of nitriding,\none lesson at a time.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(Color.ink.opacity(0.55))
                .padding(.top, 8)

            Spacer().frame(height: 32)

            // Continue with Apple
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { await handleAppleResult(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Try the demo
            Button {
                Task { await tryDemo() }
            } label: {
                Text("Try the demo")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.accentInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .disabled(signingIn)

            Text("Your progress lives on your own server.\nNothing leaves your tailnet.")
                .font(.caption).multilineTextAlignment(.center).foregroundStyle(Color.ink.opacity(0.4))
                .padding(.top, 8)

            if signingIn {
                ProgressView().padding(.top, 12)
            }

            if let error = signInError {
                signInErrorBanner(error).padding(.top, 12)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paper)
        .sheet(isPresented: $showClaim) {
            claimDismissed()
        } content: {
            if let claim = claimData {
                ClaimSheet(claim: claim).environmentObject(store)
            }
        }
        .onAppear {
            #if DEBUG && targetEnvironment(simulator)
            if Verification.screen == "signin-error" {
                signInError = "Couldn't sign in to the server. Check your connection and try again."
            }
            if Verification.screen == "claim" {
                claimData = Verification.fixtureClaimResponse
                showClaim = true
            }
            #endif
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken else {
                signInError = "Apple did not finish the sign-in, so nothing was linked or changed."
                return
            }
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            let email = credential.email
            signingIn = true; signInError = nil
            do {
                let claim = try await store.handleAppleSignIn(identityToken: identityToken)
                if !fullName.isEmpty || email != nil {
                    UserInfo.save(UserInfo(name: fullName.isEmpty ? nil : fullName, email: email))
                }
                if let claim { claimData = claim; showClaim = true }
            } catch {
                signInError = "Couldn't sign in to the server. Check your connection and try again."
            }
            signingIn = false
        case .failure:
            signInError = "Apple did not finish the sign-in, so nothing was linked or changed."
        }
    }

    private func tryDemo() async {
        signingIn = true; signInError = nil
        do { try await store.signInDemo() }
        catch { signInError = "Couldn't start the demo. Check your connection and try again." }
        signingIn = false
    }

    private func claimDismissed() {
        if store.authState == .signedOut && API.sessionToken != nil {
            Task { await store.finishSignIn() }
        }
    }

    private func signInErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.amber)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("That sign-in didn't go through")
                    .font(.subheadline.bold())
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.ink.opacity(0.55))
            }
            Spacer()
            Button("Try again") { signInError = nil }
                .font(.subheadline.weight(.medium)).foregroundStyle(Color.accentInk)
        }
        .padding(14)
        .background(Color.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Claim Sheet (Instrument styled)

struct ClaimSheet: View {
    let claim: ClaimResponse
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var claiming = false
    @State private var claimError = false
    @State private var showPreviewResult = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 8) {
                        Text("EXISTING PROGRESS ON THIS SERVER")
                            .font(.system(size: 11, weight: .bold)).tracking(1.0)
                            .foregroundStyle(Color.accentInk)
                        Text("PREVIEW")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.ink.opacity(0.08), in: Capsule())
                    }

                    Text("Your progress is here")
                        .font(.title2.bold()).tracking(-0.3)
                    Text("This preview links nothing. Check it, then decide.")
                        .font(.subheadline).foregroundStyle(Color.ink.opacity(0.55))

                    let d = claim.dataset
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        claimStatCell("XP EARNED", "\(d.xp) XP", "total so far")
                        claimStatCell("DAY STREAK", "\(d.streak) day\(d.streak == 1 ? "" : "s")", "still alive")
                        claimStatCell("LESSONS", "Unit \(d.currentUnit)",
                                     "\(d.units.first(where: { $0.unitId == d.currentUnit })?.lessonsCompleted ?? 0) of 8 done")
                        claimStatCell("SHOP RUNS", "\(d.simHistoryCount) saved", "")
                    }.padding(.vertical, 4)

                    Text("Claiming links this progress to your Apple ID. It cannot be undone from the app.")
                        .font(.subheadline).foregroundStyle(Color.ink.opacity(0.55))

                    Button {
                        Task { await performClaim() }
                    } label: {
                        Text("Claim this progress")
                            .font(.body.weight(.semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }.disabled(claiming)

                    if claimError {
                        Text("Couldn't load the preview. Please try again.")
                            .font(.subheadline).foregroundStyle(Color.danger)
                    }

                    Button { dismiss() } label: {
                        Text("Not now")
                            .font(.body.weight(.medium)).foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }.padding(24)
            }
            .background(Color.paper)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .alert("Preview only", isPresented: $showPreviewResult) {
                Button("Continue") { dismiss() }
            } message: {
                Text("No progress was linked or changed.")
            }
        }
    }

    private func claimStatCell(_ label: String, _ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(Color.ink.opacity(0.4))
            Text(value).font(.title3.bold())
            if !caption.isEmpty {
                Text(caption).font(.caption).foregroundStyle(Color.ink.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
    }

    private func performClaim() async {
        claiming = true
        defer { claiming = false }
        do {
            let result = try await store.claimProgress()
            if result.dryRun && !result.claimEnabled { showPreviewResult = true } else { claimError = true }
        } catch { claimError = true }
    }
}
