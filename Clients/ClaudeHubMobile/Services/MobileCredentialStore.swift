import ClaudeHubRemote
import CryptoKit
import Foundation
import Security

struct PairedHostRecord: Codable, Sendable {
    let relayURL: String
    let hostID: String
    let hostName: String
    let hostPublicKey: String
}

final class MobileCredentialStore {
    private let defaults: UserDefaults
    private let keychainService = "com.mariomoschetta.ClaudeHubMobile"
    private let clientIDKey = "mobile_client_id"
    private let pairedHostKey = "mobile_paired_host"
    private let privateKeyAccount = "mobile_client_signing_key"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadOrCreateClientIdentity() -> (clientID: String, signingKey: P256.Signing.PrivateKey) {
        let clientID = defaults.string(forKey: clientIDKey) ?? {
            let freshID = UUID().uuidString
            defaults.set(freshID, forKey: clientIDKey)
            return freshID
        }()

        if let storedKeyData = readKeychainData(for: privateKeyAccount),
           let signingKey = try? P256.Signing.PrivateKey(rawRepresentation: storedKeyData) {
            return (clientID, signingKey)
        }

        let signingKey = P256.Signing.PrivateKey()
        writeKeychainData(signingKey.rawRepresentation, for: privateKeyAccount)
        return (clientID, signingKey)
    }

    func savePairedHost(
        relayURL: String,
        payload: PairingSuccessPayload
    ) {
        let record = PairedHostRecord(
            relayURL: relayURL,
            hostID: payload.hostID,
            hostName: payload.hostName,
            hostPublicKey: payload.hostPublicKey
        )

        if let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: pairedHostKey)
        }
    }

    func pairedHost() -> PairedHostRecord? {
        guard let data = defaults.data(forKey: pairedHostKey) else { return nil }
        return try? JSONDecoder().decode(PairedHostRecord.self, from: data)
    }

    private func readKeychainData(for account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private func writeKeychainData(_ data: Data, for account: String) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}
