import AgenticAppleServices
import AgenticExecution
import CryptoKit
import Darwin
import Foundation
import TestFlows

extension AgenticDomainsFlowTesting {
    static func runWeatherKitRESTTokenFixture() async throws
        -> [TestFlowDiagnostic]
    {
        let privateKey = P256.Signing.PrivateKey()
        let configuration = WeatherKitRESTConfiguration(
            teamID: "TEAM123",
            keyID: "KEY123",
            serviceID: "com.example.agentic.weather",
            privateKeyPEM: privateKey.pemRepresentation,
            language: "en",
            timeZone: "Europe/Amsterdam"
        )
        let now = Date(
            timeIntervalSince1970: 1_700_000_000
        )
        let lifetime: TimeInterval = 600

        let token = try WeatherKitRESTTokenProvider.token(
            configuration: configuration,
            now: now,
            lifetime: lifetime
        )
        let parts = token.value.split(
            separator: ".",
            omittingEmptySubsequences: false
        )

        try Expect.equal(
            parts.count,
            3,
            "WeatherKit REST developer token has JWT header, payload, and signature segments"
        )

        guard parts.count == 3 else {
            throw WeatherKitRESTFlowFixtureError
                .malformedToken
        }

        let headerData = try weatherKitRESTBase64URLDecode(
            String(parts[0])
        )
        let payloadData = try weatherKitRESTBase64URLDecode(
            String(parts[1])
        )
        let signatureData = try weatherKitRESTBase64URLDecode(
            String(parts[2])
        )

        guard let header = try JSONSerialization
            .jsonObject(with: headerData)
            as? [String: Any]
        else {
            throw WeatherKitRESTFlowFixtureError
                .invalidJWTHeader
        }

        guard let payload = try JSONSerialization
            .jsonObject(with: payloadData)
            as? [String: Any]
        else {
            throw WeatherKitRESTFlowFixtureError
                .invalidJWTPayload
        }

        try Expect.true(
            header["alg"] as? String == "ES256",
            "WeatherKit REST JWT declares ES256"
        )
        try Expect.true(
            header["kid"] as? String == "KEY123",
            "WeatherKit REST JWT carries the configured key ID"
        )
        try Expect.true(
            header["id"] as? String
                == "TEAM123.com.example.agentic.weather",
            "WeatherKit REST JWT carries team plus service identifier"
        )
        try Expect.true(
            payload["iss"] as? String == "TEAM123",
            "WeatherKit REST JWT issuer is the configured team"
        )
        try Expect.true(
            payload["sub"] as? String
                == "com.example.agentic.weather",
            "WeatherKit REST JWT subject is the configured service"
        )
        try Expect.true(
            (payload["iat"] as? NSNumber)?.intValue
                == 1_700_000_000,
            "WeatherKit REST JWT uses the supplied issuance time"
        )
        try Expect.true(
            (payload["exp"] as? NSNumber)?.intValue
                == 1_700_000_600,
            "WeatherKit REST JWT uses the supplied expiration"
        )

        let signingInput =
            String(parts[0])
            + "."
            + String(parts[1])
        let signature = try P256.Signing.ECDSASignature(
            rawRepresentation: signatureData
        )

        try Expect.true(
            privateKey.publicKey.isValidSignature(
                signature,
                for: Data(signingInput.utf8)
            ),
            "WeatherKit REST JWT signature verifies with the generated P-256 public key"
        )
        try Expect.equal(
            token.expiresAt,
            now.addingTimeInterval(lifetime),
            "WeatherKit REST token exposes its exact expiration"
        )

        return [
            .field(
                "segments",
                "\(parts.count)"
            ),
            .field(
                "signature",
                "verified"
            ),
        ]
    }

    static func runWeatherKitRESTCurrentFixture() async throws
        -> [TestFlowDiagnostic]
    {
        let environment = WeatherKitRESTEnvironmentSnapshot()
        environment.clear()
        defer {
            environment.restore()
        }

        let privateKey = P256.Signing.PrivateKey()
        let configuration = WeatherKitRESTConfiguration(
            teamID: "TEAM-CURRENT",
            keyID: "KEY-CURRENT",
            serviceID: "com.example.current",
            privateKeyPEM: privateKey.pemRepresentation,
            language: "en",
            timeZone: "Europe/Amsterdam"
        )
        let body = Data(
            """
            {
              "currentWeather": {
                "asOf": "2026-09-05T18:00:00Z",
                "conditionCode": "Clear",
                "temperature": 21.5,
                "temperatureApparent": 20.75,
                "humidity": 0.64,
                "windSpeed": 18.0
              }
            }
            """.utf8
        )

        WeatherKitRESTFlowURLProtocol.prepare(
            status: 200,
            body: body
        )

        let session = weatherKitRESTFixtureSession()
        let provider = WeatherKitRESTProvider(
            configuration: configuration,
            session: session
        )
        let snapshot = try await provider.currentWeather(
            at: .init(
                latitude: 52.37,
                longitude: 4.90
            )
        )

        try Expect.equal(
            snapshot.coordinate,
            .init(
                latitude: 52.37,
                longitude: 4.90
            ),
            "WeatherKit REST current fixture preserves requested coordinate"
        )
        try Expect.equal(
            snapshot.date,
            "2026-09-05T18:00:00Z",
            "WeatherKit REST current fixture projects asOf"
        )
        try Expect.equal(
            snapshot.conditionCode,
            "Clear",
            "WeatherKit REST current fixture projects condition code"
        )
        try Expect.equal(
            snapshot.symbolName,
            nil,
            "WeatherKit REST current projection does not fabricate a native SF Symbol"
        )
        try Expect.equal(
            snapshot.temperatureCelsius,
            21.5,
            "WeatherKit REST current fixture projects temperature"
        )
        try Expect.equal(
            snapshot.apparentTemperatureCelsius,
            20.75,
            "WeatherKit REST current fixture projects apparent temperature"
        )
        try Expect.equal(
            snapshot.humidity,
            0.64,
            "WeatherKit REST current fixture projects humidity"
        )
        try Expect.true(
            abs(
                snapshot.windSpeedMetersPerSecond
                    - 5.0
            ) < 0.000_001,
            "WeatherKit REST converts wind speed from kilometers per hour to meters per second"
        )

        let requests = WeatherKitRESTFlowURLProtocol
            .recordedRequests()

        try Expect.equal(
            requests.count,
            1,
            "WeatherKit REST current fixture performs exactly one HTTP request"
        )

        guard let request = requests.first,
              let url = request.url
        else {
            throw WeatherKitRESTFlowFixtureError
                .missingRequest
        }

        try Expect.equal(
            url.host,
            "weatherkit.apple.com",
            "WeatherKit REST request targets Apple's WeatherKit host"
        )
        try Expect.equal(
            url.path,
            "/api/v1/weather/en/52.37/4.9",
            "WeatherKit REST current request contains language and explicit coordinate"
        )

        let query = weatherKitRESTQueryItems(
            url
        )

        try Expect.equal(
            query["dataSets"],
            "currentWeather",
            "WeatherKit REST current request asks only for currentWeather"
        )
        try Expect.equal(
            query["timezone"],
            "Europe/Amsterdam",
            "WeatherKit REST current request projects configured timezone"
        )

        let authorization = request.value(
            forHTTPHeaderField: "Authorization"
        ) ?? ""

        try Expect.true(
            authorization.hasPrefix("Bearer "),
            "WeatherKit REST current request carries a bearer developer token"
        )

        let bearer = String(
            authorization.dropFirst("Bearer ".count)
        )

        try Expect.equal(
            bearer.split(separator: ".").count,
            3,
            "WeatherKit REST current request bearer value is a JWT"
        )

        return [
            .field(
                "condition",
                snapshot.conditionCode
            ),
            .field(
                "requests",
                "\(requests.count)"
            ),
            .field(
                "environment",
                "explicit-configuration"
            ),
        ]
    }

    static func runWeatherKitRESTForecastFixture() async throws
        -> [TestFlowDiagnostic]
    {
        let privateKey = P256.Signing.PrivateKey()
        let configuration = WeatherKitRESTConfiguration(
            teamID: "TEAM-FORECAST",
            keyID: "KEY-FORECAST",
            serviceID: "com.example.forecast",
            privateKeyPEM: privateKey.pemRepresentation,
            language: "nl",
            timeZone: "UTC"
        )
        let body = Data(
            """
            {
              "forecastHourly": {
                "hours": [
                  {
                    "forecastStart": "2026-09-05T19:00:00Z",
                    "conditionCode": "Cloudy",
                    "temperature": 18.5,
                    "precipitationChance": 0.25
                  },
                  {
                    "forecastStart": "2026-09-05T20:00:00Z",
                    "conditionCode": "Rain",
                    "temperature": 17.0,
                    "precipitationChance": 0.75
                  }
                ]
              },
              "forecastDaily": {
                "days": [
                  {
                    "forecastStart": "2026-09-05T00:00:00Z",
                    "conditionCode": "Cloudy",
                    "temperatureMin": 12.0,
                    "temperatureMax": 22.0,
                    "precipitationChance": 0.30
                  },
                  {
                    "forecastStart": "2026-09-06T00:00:00Z",
                    "conditionCode": "Rain",
                    "temperatureMin": 11.0,
                    "temperatureMax": 19.0,
                    "precipitationChance": 0.80
                  }
                ]
              }
            }
            """.utf8
        )

        WeatherKitRESTFlowURLProtocol.prepare(
            status: 200,
            body: body
        )

        let provider = WeatherKitRESTProvider(
            configuration: configuration,
            session: weatherKitRESTFixtureSession()
        )
        let forecast = try await provider.forecast(
            at: .init(
                latitude: 40.0,
                longitude: -74.0
            ),
            hours: 1,
            days: 1
        )

        try Expect.equal(
            forecast.hourly.count,
            1,
            "WeatherKit REST forecast applies requested hourly bound"
        )
        try Expect.equal(
            forecast.daily.count,
            1,
            "WeatherKit REST forecast applies requested daily bound"
        )
        try Expect.equal(
            forecast.hourly.first?.conditionCode,
            "Cloudy",
            "WeatherKit REST hourly fixture projects condition code"
        )
        try Expect.equal(
            forecast.hourly.first?.temperatureCelsius,
            18.5,
            "WeatherKit REST hourly fixture projects temperature"
        )
        try Expect.equal(
            forecast.hourly.first?.precipitationChance,
            0.25,
            "WeatherKit REST hourly fixture projects precipitation chance"
        )
        try Expect.equal(
            forecast.hourly.first?.symbolName,
            nil,
            "WeatherKit REST hourly projection keeps native symbol absent"
        )
        try Expect.equal(
            forecast.daily.first?.conditionCode,
            "Cloudy",
            "WeatherKit REST daily fixture projects condition code"
        )
        try Expect.equal(
            forecast.daily.first?.lowTemperatureCelsius,
            12.0,
            "WeatherKit REST daily fixture projects low temperature"
        )
        try Expect.equal(
            forecast.daily.first?.highTemperatureCelsius,
            22.0,
            "WeatherKit REST daily fixture projects high temperature"
        )
        try Expect.equal(
            forecast.daily.first?.precipitationChance,
            0.30,
            "WeatherKit REST daily fixture projects precipitation chance"
        )

        let requests = WeatherKitRESTFlowURLProtocol
            .recordedRequests()

        try Expect.equal(
            requests.count,
            1,
            "WeatherKit REST forecast fixture performs exactly one HTTP request"
        )

        guard let url = requests.first?.url else {
            throw WeatherKitRESTFlowFixtureError
                .missingRequest
        }

        try Expect.equal(
            url.path,
            "/api/v1/weather/nl/40.0/-74.0",
            "WeatherKit REST forecast request projects configured language and coordinate"
        )

        let query = weatherKitRESTQueryItems(
            url
        )

        try Expect.equal(
            query["dataSets"],
            "forecastHourly,forecastDaily",
            "WeatherKit REST forecast requests hourly and daily datasets together"
        )
        try Expect.equal(
            query["timezone"],
            "UTC",
            "WeatherKit REST forecast request projects configured timezone"
        )

        return [
            .field(
                "hourly",
                "\(forecast.hourly.count)"
            ),
            .field(
                "daily",
                "\(forecast.daily.count)"
            ),
        ]
    }

    static func runWeatherKitRESTConfigurationBoundary() async throws
        -> [TestFlowDiagnostic]
    {
        WeatherKitRESTFlowURLProtocol.reset()

        let environment = WeatherKitRESTEnvironmentSnapshot()
        environment.clear()
        defer {
            environment.restore()
        }

        var registry = ToolRegistry()

        try registry.register(
            AgenticAppleServicesToolSet()
        )
        try Expect.equal(
            registry.count,
            12,
            "AgenticAppleServices registration remains credential-free with WeatherKit REST as the default provider"
        )

        let provider = WeatherKitRESTProvider()
        var invalidCoordinateObserved = false

        do {
            _ = try await provider.currentWeather(
                at: .init(
                    latitude: 999,
                    longitude: 4.9
                )
            )
        } catch let error as WeatherKitRESTProviderError {
            if case .invalidLatitude(let latitude) = error {
                invalidCoordinateObserved =
                    latitude == 999
            }
        }

        try Expect.true(
            invalidCoordinateObserved,
            "WeatherKit REST rejects invalid coordinates before environment configuration or network access"
        )
        try Expect.equal(
            WeatherKitRESTFlowURLProtocol
                .recordedRequests()
                .count,
            0,
            "WeatherKit REST invalid-coordinate validation performs no HTTP request"
        )

        var missingEnvironmentObserved = false

        do {
            _ = try await provider.currentWeather(
                at: .init(
                    latitude: 52.37,
                    longitude: 4.9
                )
            )
        } catch {
            missingEnvironmentObserved =
                error.localizedDescription.contains(
                    "AGENTIC_WEATHERKIT_TEAM_ID"
                )
        }

        try Expect.true(
            missingEnvironmentObserved,
            "WeatherKit REST resolves credentials lazily and reports the first missing environment variable only on actual weather use"
        )
        try Expect.equal(
            WeatherKitRESTFlowURLProtocol
                .recordedRequests()
                .count,
            0,
            "Missing WeatherKit REST environment configuration fails before any network request"
        )

        return [
            .field(
                "registered",
                "\(registry.count)"
            ),
            .field(
                "configuration",
                "lazy"
            ),
            .field(
                "network",
                "none"
            ),
        ]
    }
}

private enum WeatherKitRESTFlowFixtureError:
    Error,
    LocalizedError
{
    case malformedToken
    case invalidBase64URL(String)
    case invalidJWTHeader
    case invalidJWTPayload
    case missingRequest

    var errorDescription: String? {
        switch self {
        case .malformedToken:
            return "WeatherKit REST fixture produced a malformed JWT."

        case .invalidBase64URL(let value):
            return "WeatherKit REST fixture could not decode base64url value: \(value)"

        case .invalidJWTHeader:
            return "WeatherKit REST fixture JWT header was not a JSON object."

        case .invalidJWTPayload:
            return "WeatherKit REST fixture JWT payload was not a JSON object."

        case .missingRequest:
            return "WeatherKit REST fixture did not capture the expected URL request."
        }
    }
}

private func weatherKitRESTBase64URLDecode(
    _ value: String
) throws -> Data {
    var base64 = value
        .replacingOccurrences(
            of: "-",
            with: "+"
        )
        .replacingOccurrences(
            of: "_",
            with: "/"
        )

    let remainder = base64.count % 4

    if remainder != 0 {
        base64 += String(
            repeating: "=",
            count: 4 - remainder
        )
    }

    guard let data = Data(
        base64Encoded: base64
    ) else {
        throw WeatherKitRESTFlowFixtureError
            .invalidBase64URL(value)
    }

    return data
}

private func weatherKitRESTQueryItems(
    _ url: URL
) -> [String: String] {
    guard let components = URLComponents(
        url: url,
        resolvingAgainstBaseURL: false
    ) else {
        return [:]
    }

    return Dictionary(
        uniqueKeysWithValues:
            (components.queryItems ?? [])
                .compactMap { item in
                    guard let value = item.value else {
                        return nil
                    }

                    return (
                        item.name,
                        value
                    )
                }
    )
}

private func weatherKitRESTFixtureSession()
    -> URLSession
{
    let configuration = URLSessionConfiguration
        .ephemeral
    configuration.protocolClasses = [
        WeatherKitRESTFlowURLProtocol.self,
    ]

    return URLSession(
        configuration: configuration
    )
}

private struct WeatherKitRESTEnvironmentSnapshot {
    private static let keys = [
        "AGENTIC_WEATHERKIT_TEAM_ID",
        "AGENTIC_WEATHERKIT_KEY_ID",
        "AGENTIC_WEATHERKIT_SERVICE_ID",
        "AGENTIC_WEATHERKIT_PRIVATE_KEY_PATH",
    ]

    private let values: [(
        key: String,
        value: String?
    )]

    init() {
        values = Self.keys.map { key in
            (
                key,
                ProcessInfo.processInfo
                    .environment[key]
            )
        }
    }

    func clear() {
        for key in Self.keys {
            _ = unsetenv(key)
        }
    }

    func restore() {
        for entry in values {
            if let value = entry.value {
                _ = setenv(
                    entry.key,
                    value,
                    1
                )
            } else {
                _ = unsetenv(
                    entry.key
                )
            }
        }
    }
}

private final class WeatherKitRESTFlowURLProtocol:
    URLProtocol,
    @unchecked Sendable
{
    private struct Fixture: Sendable {
        let status: Int
        let headers: [String: String]
        let body: Data
    }

    private final class State:
        @unchecked Sendable
    {
        private let lock = NSLock()
        private var fixture: Fixture?
        private var requests: [URLRequest] = []

        func prepare(
            status: Int,
            headers: [String: String],
            body: Data
        ) {
            lock.lock()
            defer {
                lock.unlock()
            }

            fixture = .init(
                status: status,
                headers: headers,
                body: body
            )
            requests = []
        }

        func record(
            _ request: URLRequest
        ) -> Fixture? {
            lock.lock()
            defer {
                lock.unlock()
            }

            requests.append(request)
            return fixture
        }

        func recordedRequests()
            -> [URLRequest]
        {
            lock.lock()
            defer {
                lock.unlock()
            }

            return requests
        }

        func reset() {
            lock.lock()
            defer {
                lock.unlock()
            }

            fixture = nil
            requests = []
        }
    }

    private static let state = State()

    static func prepare(
        status: Int,
        headers: [String: String] = [
            "Content-Type": "application/json",
        ],
        body: Data
    ) {
        state.prepare(
            status: status,
            headers: headers,
            body: body
        )
    }

    static func recordedRequests()
        -> [URLRequest]
    {
        state.recordedRequests()
    }

    static func reset() {
        state.reset()
    }

    override class func canInit(
        with request: URLRequest
    ) -> Bool {
        true
    }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let fixture = Self.state.record(
            request
        ),
        let url = request.url,
        let response = HTTPURLResponse(
            url: url,
            statusCode: fixture.status,
            httpVersion: "HTTP/1.1",
            headerFields: fixture.headers
        ) else {
            client?.urlProtocol(
                self,
                didFailWithError:
                    URLError(.badServerResponse)
            )
            return
        }

        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(
            self,
            didLoad: fixture.body
        )
        client?.urlProtocolDidFinishLoading(
            self
        )
    }

    override func stopLoading() {}
}
