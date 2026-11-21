import Foundation
import SwiftUI

enum APIError: Error { case unauthorized, notFound }

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
        if http.statusCode == 404 { throw APIError.notFound }
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
    @Published var course: Course?
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
            if screen == "signin" || screen == "signin-error" || screen == "claim" || screen == "auth-flow" {
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
            do {
                state = try await API.request("api/state")
                authState = slot == .demo ? .demo : .signedIn
                await refresh()
            } catch {
                API.sessionToken = nil
                authState = .signedOut
            }
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
        // Verify the issued session and load server-owned progress before entering the app.
        do {
            state = try await API.request("api/state")
        } catch {
            SessionKeychain.delete(.real)
            API.sessionToken = nil
            UserDefaults.standard.removeObject(forKey: "active_session")
            throw error
        }
        // Check for claimable legacy progress
        do {
            let claim: ClaimResponse = try await API.request("api/claim", body: Data("{}".utf8))
            if claim.dataset.xp > 0 {
                return claim
            }
        } catch APIError.notFound { /* No legacy dataset exists. */ }
        catch {
            SessionKeychain.delete(.real)
            API.sessionToken = nil
            UserDefaults.standard.removeObject(forKey: "active_session")
            state = nil
            throw error
        }
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
        guard authState == .demo, API.sessionToken == auth.sessionToken else { throw APIError.unauthorized }
    }

    func signOut() {
        let token = API.sessionToken
        SessionKeychain.delete(.demo)
        SessionKeychain.delete(.real)
        UserInfo.clear()
        API.sessionToken = nil
        UserDefaults.standard.removeObject(forKey: "active_session")
        state = nil; bank = nil; queue = nil; tutor = nil
        failed = false; loading = false; tutorFailed = false
        authState = .signedOut
        if let token, Verification.screen == nil {
            Task {
                var request = URLRequest(url: API.base.appendingPathComponent("api/auth/logout"))
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: request)
            }
        }
    }

    func finishSignIn() async {
        guard API.sessionToken != nil, SessionKeychain.read(.real) != nil else { signOut(); return }
        authState = .signedIn; await refresh()
    }

    func claimProgress() async throws -> ClaimResponse {
        try await API.request("api/claim", body: Data("{}".utf8))
    }

    func generatePairingCode() async throws -> PairResponse {
        let body = try JSONSerialization.data(withJSONObject: ["action": "generate"])
        return try await API.request("api/auth/pair", body: body)
    }

    // MARK: - Data refresh
    func refresh() async {
        guard let token = API.sessionToken, authState == .signedIn || authState == .demo else { return }
        guard !loading else { return }; loading = true
        defer { loading = false }
        do {
            let progress: ProgressState = try await API.request("api/state")
            guard API.sessionToken == token else { return }
            state = progress
            let content: Bank = try await API.request("data/questions.json")
            guard API.sessionToken == token else { return }
            bank = content
            course = try await API.request("data/course.json")
            let reviews: [ReviewItem] = try await API.request("api/review-queue")
            guard API.sessionToken == token else { return }
            queue = reviews; failed = false
        } catch APIError.unauthorized {
            if API.sessionToken == token { signOut() }; return
        } catch { if API.sessionToken == token { failed = true } }
        guard API.sessionToken == token else { return }
        do { let result: Tutor = try await API.request("api/tutor"); guard API.sessionToken == token else { return }; tutor = result; tutorFailed = false } catch {
            guard API.sessionToken == token else { return }
            if case APIError.unauthorized = error { signOut(); return }
            tutorFailed = true
        }
    }
    var questions: [Question] { bank?.questions ?? [] }
    var reviewQuestions: [Question] { (queue ?? []).compactMap { item in questions.first { $0.id == item.question_id } } }
}
