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
            // App icon
            Image(systemName: "flame.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text("FurnacePath")
                .font(.largeTitle.bold())
                .padding(.top, 16)

            Text("Learn the business of nitriding,\none lesson at a time.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.ink.opacity(0.55))
                .padding(.top, 8)

            Spacer().frame(height: 26)

            // Continue with Apple
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { await handleAppleResult(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Try the demo
            Button {
                Task { await tryDemo() }
            } label: {
                Text("Try the demo")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.orangeAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .disabled(signingIn)

            Text("Your progress lives on your own server.\nNothing leaves your tailnet.")
                .font(.caption).multilineTextAlignment(.center).foregroundStyle(Color.ink.opacity(0.6))
                .padding(.top, 8)

            if signingIn {
                ProgressView().padding(.bottom, 8)
            }

            if let error = signInError {
                signInErrorBanner(error)
                    .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.bottom, 24)
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paper)
        .sheet(isPresented: $showClaim) {
            claimDismissed()
        } content: {
            if let claim = claimData {
                ClaimSheet(claim: claim)
                    .environmentObject(store)
            }
        }
        .onAppear {
            #if DEBUG && targetEnvironment(simulator)
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
            // Save user info from credential (only available on first sign-in)
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            let email = credential.email
            signingIn = true; signInError = nil
            do {
                let claim = try await store.handleAppleSignIn(identityToken: identityToken)
                if !fullName.isEmpty || email != nil {
                    UserInfo.save(UserInfo(name: fullName.isEmpty ? nil : fullName, email: email))
                }
                if let claim {
                    claimData = claim; showClaim = true
                }
            } catch {
                signInError = "Apple did not finish the sign-in, so nothing was linked or changed."
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
                    .foregroundStyle(Color.ink.opacity(0.65))
            }
            Spacer()
            Button("Try again") { signInError = nil }
                .font(.subheadline.weight(.medium))
        }
        .padding(14)
        .background(Color.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Claim confirmation sheet
struct ClaimSheet: View {
    let claim: ClaimResponse
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var claiming = false
    @State private var claimError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(spacing: 8) {
                        Text("EXISTING PROGRESS ON THIS SERVER")
                            .font(.caption.bold())
                            .foregroundStyle(Color.orangeAccent)
                        Text("PREVIEW")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.ink.opacity(0.08), in: Capsule())
                    }

                    Text("Your progress is here")
                        .font(.title2.bold())
                    Text("This preview links nothing. Check it, then decide.")
                        .foregroundStyle(Color.ink.opacity(0.55))

                    // Stats grid
                    let d = claim.dataset
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        statCell("XP EARNED", "\(d.xp) XP", "total so far")
                        statCell("DAY STREAK", "\(d.streak) day\(d.streak == 1 ? "" : "s")", "still alive")
                        statCell("LESSONS", "Unit \(d.currentUnit)", "\(d.units.first(where: { $0.unitId == d.currentUnit })?.lessonsCompleted ?? 0) of \(8) done")
                        statCell("SHOP RUNS", "\(d.simHistoryCount) saved", "")
                    }
                    .padding(.vertical, 4)

                    // Warning
                    Text("Claiming links this progress to your Apple ID. It cannot be undone from the app.")
                        .font(.subheadline)
                        .foregroundStyle(Color.ink.opacity(0.55))

                    // Claim button
                    Button {
                        Task { await performClaim() }
                    } label: {
                        Text("Claim this progress")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orangeAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(claiming)

                    if claimError { Text("Couldn’t load the preview. Please try again.").foregroundStyle(Color.ink) }

                    // Not now button
                    Button {
                        dismiss()
                    } label: {
                        Text("Not now")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(24)
            }
            .background(Color.paper)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func statCell(_ label: String, _ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(Color.ink.opacity(0.5))
            Text(value)
                .font(.title3.bold())
            Text(caption)
                .font(.caption)
                .foregroundStyle(Color.ink.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func performClaim() async {
        claiming = true
        defer { claiming = false }
        // Dry-run only: calls /api/claim, which currently returns dryRun: true
        do {
            let result = try await store.claimProgress()
            if result.dryRun && !result.claimEnabled { dismiss() }
        } catch { claimError = true }
    }
}
