import ClaudeHubRemote
import Foundation

enum QRCodePairingParser {
    static func parse(_ rawValue: String) throws -> PairingQRCodePayload {
        guard let data = rawValue.data(using: .utf8) else {
            throw ParserError.invalidEncoding
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PairingQRCodePayload.self, from: data)
    }

    enum ParserError: LocalizedError {
        case invalidEncoding

        var errorDescription: String? {
            switch self {
            case .invalidEncoding:
                return "The QR payload is not valid UTF-8 text."
            }
        }
    }
}
