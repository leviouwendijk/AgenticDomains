import CryptoKit
import Foundation

public struct WeatherKitRESTDeveloperToken:
    Sendable,
    Hashable
{
    public let value: String
    public let expiresAt: Date

    public init(
        value: String,
        expiresAt: Date
    ) {
        self.value = value
        self.expiresAt = expiresAt
    }
}

public enum WeatherKitRESTTokenProvider {
    public static func token(
        configuration: WeatherKitRESTConfiguration,
        now: Date = .init(),
        lifetime: TimeInterval = 50 * 60
    ) throws -> WeatherKitRESTDeveloperToken {
        let issuedAt = Int(
            now.timeIntervalSince1970
        )
        let expiration = now.addingTimeInterval(
            lifetime
        )
        let expiresAt = Int(
            expiration.timeIntervalSince1970
        )

        let header = Header(
            alg: "ES256",
            kid: configuration.keyID,
            id:
                configuration.teamID
                + "."
                + configuration.serviceID
        )
        let payload = Payload(
            iss: configuration.teamID,
            iat: issuedAt,
            exp: expiresAt,
            sub: configuration.serviceID
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let encodedHeader = base64URL(
            try encoder.encode(header)
        )
        let encodedPayload = base64URL(
            try encoder.encode(payload)
        )
        let signingInput =
            encodedHeader
            + "."
            + encodedPayload

        let privateKey = try P256.Signing.PrivateKey(
            pemRepresentation:
                configuration.privateKeyPEM
        )
        let signature = try privateKey.signature(
            for: Data(signingInput.utf8)
        )

        return .init(
            value:
                signingInput
                + "."
                + base64URL(
                    signature.rawRepresentation
                ),
            expiresAt: expiration
        )
    }
}

private extension WeatherKitRESTTokenProvider {
    struct Header: Encodable {
        let alg: String
        let kid: String
        let id: String
    }

    struct Payload: Encodable {
        let iss: String
        let iat: Int
        let exp: Int
        let sub: String
    }

    static func base64URL(
        _ data: Data
    ) -> String {
        data.base64EncodedString()
            .replacingOccurrences(
                of: "+",
                with: "-"
            )
            .replacingOccurrences(
                of: "/",
                with: "_"
            )
            .replacingOccurrences(
                of: "=",
                with: ""
            )
    }
}
