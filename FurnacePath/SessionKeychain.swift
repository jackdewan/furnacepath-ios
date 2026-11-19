import Foundation
import Security

/// Separate credentials prevent a demo session from overwriting a real session.
enum SessionKeychain {
    enum Slot: String { case real, demo }
    private static let service = "com.jackdewan.furnacepath.session"
    #if DEBUG && targetEnvironment(simulator)
    private static var verificationSessions: [Slot: String] = [:]
    #endif

    static func read(_ slot: Slot) -> String? {
        #if DEBUG && targetEnvironment(simulator)
        if Verification.screen != nil { return verificationSessions[slot] }
        #endif
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: slot.rawValue,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult static func write(_ token: String, to slot: Slot) -> Bool {
        #if DEBUG && targetEnvironment(simulator)
        if Verification.screen != nil { verificationSessions[slot] = token; return true }
        #endif
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: slot.rawValue]
        let data = Data(token.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func delete(_ slot: Slot) {
        #if DEBUG && targetEnvironment(simulator)
        if Verification.screen != nil { verificationSessions.removeValue(forKey: slot); return }
        #endif
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: slot.rawValue]
        SecItemDelete(query as CFDictionary)
    }
}
