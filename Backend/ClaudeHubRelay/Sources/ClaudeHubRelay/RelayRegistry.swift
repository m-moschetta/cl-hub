import ClaudeHubRemote
import CryptoKit
import Foundation
import NIOConcurrencyHelpers
import Vapor

struct HostRegistration: Sendable {
    let displayName: String
    let publicKey: String
    let appVersion: String
    let platform: String
}

struct PendingChallenge: Sendable {
    let nonce: String
    let expiresAt: Date
}

struct PendingClientChallenge: Sendable {
    let hostID: String
    let nonce: String
    let expiresAt: Date
}

struct PairingChallenge: Sendable {
    let challengeID: String
    let hostID: String
    let nonce: String
    let expiresAt: Date
}

struct PendingPairingRequest: Sendable {
    let hostID: String
    let clientID: String
    let deviceName: String
    let publicKey: String
    let challengeID: String
}

final class RelayRegistry: @unchecked Sendable {
    private let lock = NIOLock()
    private var hostSockets: [String: WebSocket] = [:]
    private var clientSockets: [String: WebSocket] = [:]
    private var hostRegistrations: [String: HostRegistration] = [:]
    private var pendingChallenges: [String: PendingChallenge] = [:]
    private var pendingClientChallenges: [String: PendingClientChallenge] = [:]
    private var pairingChallenges: [String: PairingChallenge] = [:]
    private var pendingPairingRequests: [String: PendingPairingRequest] = [:]
    private var trustedClients: [String: [String: String]] = [:]

    func setHostSocket(_ socket: WebSocket, for hostID: String) {
        lock.withLockVoid {
            hostSockets[hostID] = socket
        }
    }

    func removeHostSocket(for hostID: String) {
        lock.withLockVoid {
            hostSockets.removeValue(forKey: hostID)
        }
    }

    func hostSocket(for hostID: String) -> WebSocket? {
        lock.withLock {
            hostSockets[hostID]
        }
    }

    func setClientSocket(_ socket: WebSocket, for clientID: String) {
        lock.withLockVoid {
            clientSockets[clientID] = socket
        }
    }

    func removeClientSocket(for clientID: String) {
        lock.withLockVoid {
            clientSockets.removeValue(forKey: clientID)
        }
    }

    func clientSocket(for clientID: String) -> WebSocket? {
        lock.withLock {
            clientSockets[clientID]
        }
    }

    func registerHost(_ payload: HostRegisterPayload, for hostID: String) {
        let registration = HostRegistration(
            displayName: payload.displayName,
            publicKey: payload.publicKey,
            appVersion: payload.appVersion,
            platform: payload.platform
        )

        lock.withLockVoid {
            hostRegistrations[hostID] = registration
        }
    }

    func createChallenge(for hostID: String, ttl: TimeInterval = 60) -> PendingChallenge {
        let challenge = PendingChallenge(
            nonce: makeNonce(),
            expiresAt: Date().addingTimeInterval(ttl)
        )

        lock.withLockVoid {
            pendingChallenges[hostID] = challenge
        }

        return challenge
    }

    func createClientChallenge(clientID: String, hostID: String, ttl: TimeInterval = 60) -> PendingClientChallenge? {
        let isTrusted = lock.withLock {
            trustedClients[hostID]?[clientID] != nil
        }

        guard isTrusted else { return nil }

        let challenge = PendingClientChallenge(
            hostID: hostID,
            nonce: makeNonce(),
            expiresAt: Date().addingTimeInterval(ttl)
        )

        lock.withLockVoid {
            pendingClientChallenges[clientID] = challenge
        }

        return challenge
    }

    func verifyHostSignature(hostID: String, nonce: String, signature: String) -> Bool {
        let snapshot: (HostRegistration?, PendingChallenge?) = lock.withLock {
            (hostRegistrations[hostID], pendingChallenges[hostID])
        }

        guard let registration = snapshot.0,
              let challenge = snapshot.1,
              challenge.nonce == nonce,
              challenge.expiresAt > Date(),
              let keyData = Data(base64Encoded: registration.publicKey),
              let signatureData = Data(base64Encoded: signature),
              let publicKey = try? P256.Signing.PublicKey(rawRepresentation: keyData),
              let ecdsaSignature = try? P256.Signing.ECDSASignature(derRepresentation: signatureData),
              publicKey.isValidSignature(ecdsaSignature, for: Data(nonce.utf8))
        else {
            return false
        }

        lock.withLockVoid {
            pendingChallenges.removeValue(forKey: hostID)
        }
        return true
    }

    func verifyClientSignature(clientID: String, nonce: String, signature: String) -> Bool {
        let snapshot: (PendingClientChallenge?, String?) = lock.withLock {
            let challenge = pendingClientChallenges[clientID]
            let publicKey = challenge.flatMap { trustedClients[$0.hostID]?[clientID] }
            return (challenge, publicKey)
        }

        guard let challenge = snapshot.0,
              let publicKeyBase64 = snapshot.1,
              challenge.nonce == nonce,
              challenge.expiresAt > Date(),
              let keyData = Data(base64Encoded: publicKeyBase64),
              let signatureData = Data(base64Encoded: signature),
              let publicKey = try? P256.Signing.PublicKey(rawRepresentation: keyData),
              let ecdsaSignature = try? P256.Signing.ECDSASignature(derRepresentation: signatureData),
              publicKey.isValidSignature(ecdsaSignature, for: Data(nonce.utf8))
        else {
            return false
        }

        lock.withLockVoid {
            pendingClientChallenges.removeValue(forKey: clientID)
        }

        return true
    }

    func createPairingChallenge(for hostID: String, ttl: TimeInterval = 60) -> PairingChallenge {
        let challenge = PairingChallenge(
            challengeID: UUID().uuidString,
            hostID: hostID,
            nonce: makeNonce(),
            expiresAt: Date().addingTimeInterval(ttl)
        )

        lock.withLockVoid {
            pairingChallenges[challenge.challengeID] = challenge
        }

        return challenge
    }

    func beginPairingRequest(_ payload: PairingRequestPayload, clientID: String) -> PendingPairingRequest? {
        let validChallenge = lock.withLock {
            pairingChallenges[payload.challengeID]
        }

        guard let challenge = validChallenge,
              challenge.hostID == payload.hostID,
              challenge.nonce == payload.nonce,
              challenge.expiresAt > Date()
        else {
            return nil
        }

        let request = PendingPairingRequest(
            hostID: payload.hostID,
            clientID: clientID,
            deviceName: payload.deviceName,
            publicKey: payload.publicKey,
            challengeID: payload.challengeID
        )

        lock.withLockVoid {
            pendingPairingRequests[payload.challengeID] = request
        }

        return request
    }

    func approvePairing(hostID: String, clientID: String, challengeID: String) -> PendingPairingRequest? {
        let request = lock.withLock {
            pendingPairingRequests[challengeID]
        }

        guard let request,
              request.hostID == hostID,
              request.clientID == clientID
        else {
            return nil
        }

        lock.withLockVoid {
            pendingPairingRequests.removeValue(forKey: challengeID)
            pairingChallenges.removeValue(forKey: challengeID)

            var clients = trustedClients[hostID] ?? [:]
            clients[clientID] = request.publicKey
            trustedClients[hostID] = clients
        }

        return request
    }

    func hostRegistration(for hostID: String) -> HostRegistration? {
        lock.withLock {
            hostRegistrations[hostID]
        }
    }

    private func makeNonce() -> String {
        Data(UUID().uuidString.utf8).base64EncodedString()
    }
}
