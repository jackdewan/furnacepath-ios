import Foundation
import SwiftUI

enum APIError: Error { case unauthorized }

struct API {
    static let base = URL(string: "http://100.87.179.24:3011")!
    static var sessionToken: String?
    static func request<T: Decodable>(_ path: String, body: Data? = nil) async throws -> T {
        if Verification.screen != nil { return try Verification.response(path, body: body) }
        var request = URLRequest(url: base.appendingPathComponent(path), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        if let token = sessionToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body { request.httpMethod = "POST"; request.httpBody = body; request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            if request.value(forHTTPHeaderField: "Authorization") != nil {
                await MainActor.run { NotificationCenter.default.post(name: .networkUnavailable, object: nil) }
            }
            throw error
        }
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 401 {
            if let sent = request.value(forHTTPHeaderField: "Authorization") {
                await MainActor.run { NotificationCenter.default.post(name: .sessionUnauthorized, object: sent) }
            }
            throw APIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }
    static func updateReview(questionId: String, correct: Bool) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["questionId": questionId, "correct": correct])
        let _: [String: Bool] = try await request("api/update-review", body: body)
    }
}

extension Notification.Name {
    static let sessionUnauthorized = Notification.Name("sessionUnauthorized")
    static let networkUnavailable = Notification.Name("networkUnavailable")
}

@MainActor final class Store: ObservableObject {
    enum AuthState { case unknown, signedOut, signedIn, demo }
    @Published var authState: AuthState = .unknown
    @Published var state: ProgressState?
    @Published var bank: Bank?
    @Published var queue: [ReviewItem]?
    @Published var tutor: Tutor?
    @Published var failed = false
    @Published var loading = false
    @Published var tutorFailed = false

    init() {
        NotificationCenter.default.addObserver(forName: .networkUnavailable, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.authState == .signedIn || self.authState == .demo else { return }
                self.failed = true
            }
        }
        NotificationCenter.default.addObserver(forName: .sessionUnauthorized, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                guard let self, let token = API.sessionToken,
                      note.object as? String == "Bearer \(token)" else { return }
                self.signOut()
            }
        }
    }

    var isDemo: Bool { authState == .demo }

    // MARK: - Bootstrap
    func bootstrap() async {
        #if DEBUG && targetEnvironment(simulator)
        if let screen = Verification.screen {
            if screen == "signin" || screen == "claim" {
                authState = .signedOut; return
            }
            if screen == "profile-demo" {
                API.sessionToken = "verify-fixture"
                authState = .demo
                await refresh(); return
            }
            API.sessionToken = "verify-fixture"
            authState = .signedIn
            await refresh(); return
        }
        #endif
        let slot: SessionKeychain.Slot = UserDefaults.standard.string(forKey: "active_session") == "demo" ? .demo : .real
        if let token = SessionKeychain.read(slot) {
            API.sessionToken = token
            await refresh()
            if authState == .unknown { authState = slot == .demo ? .demo : .signedIn }
        } else {
            authState = .signedOut
        }
    }

    // MARK: - Auth actions
    func handleAppleSignIn(identityToken: Data) async throws -> ClaimResponse? {
        guard let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        let body = try JSONSerialization.data(withJSONObject: ["identityToken": tokenString])
        let auth: AuthResponse = try await API.request("api/auth/apple", body: body)
        guard SessionKeychain.write(auth.sessionToken, to: .real) else { throw URLError(.cannotWriteToFile) }
        API.sessionToken = auth.sessionToken
        UserDefaults.standard.set("real", forKey: "active_session")
        // Check for claimable legacy progress
        do {
            let claim: ClaimResponse = try await API.request("api/claim", body: Data("{}".utf8))
            if claim.dataset.xp > 0 {
                return claim
            }
        } catch APIError.unauthorized { throw APIError.unauthorized }
        catch { /* No claimable progress or endpoint error — proceed */ }
        authState = .signedIn
        await refresh()
        return nil
    }

    func signInDemo() async throws {
        let auth: AuthResponse = try await API.request("api/auth/demo", body: Data("{}".utf8))
        guard SessionKeychain.write(auth.sessionToken, to: .demo) else { throw URLError(.cannotWriteToFile) }
        API.sessionToken = auth.sessionToken
        UserDefaults.standard.set("demo", forKey: "active_session")
        authState = .demo
        await refresh()
    }

    func signOut() {
        SessionKeychain.delete(isDemo ? .demo : .real)
        if !isDemo { UserInfo.clear() }
        API.sessionToken = nil
        UserDefaults.standard.removeObject(forKey: "active_session")
        state = nil; bank = nil; queue = nil; tutor = nil
        failed = false; loading = false
        authState = .signedOut
    }

    func finishSignIn() async { authState = .signedIn; await refresh() }

    func claimProgress() async throws -> ClaimResponse {
        try await API.request("api/claim", body: Data("{}".utf8))
    }

    func generatePairingCode() async throws -> PairResponse {
        let body = try JSONSerialization.data(withJSONObject: ["action": "generate"])
        return try await API.request("api/auth/pair", body: body)
    }

    // MARK: - Data refresh
    func refresh() async {
        guard !loading else { return }; loading = true
        defer { loading = false }
        do {
            let progress: ProgressState = try await API.request("api/state")
            state = progress
            let content: Bank = try await API.request("data/questions.json")
            bank = content
            let reviews: [ReviewItem] = try await API.request("api/review-queue")
            queue = reviews; failed = false
        } catch APIError.unauthorized {
            signOut(); return
        } catch { failed = true }
        do { tutor = try await API.request("api/tutor"); tutorFailed = false } catch {
            if case APIError.unauthorized = error { signOut(); return }
            tutorFailed = true
        }
    }
    var questions: [Question] { bank?.questions ?? [] }
    var reviewQuestions: [Question] { (queue ?? []).compactMap { item in questions.first { $0.id == item.question_id } } }
}
