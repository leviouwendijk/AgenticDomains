import Foundation
import Parsers

public struct WebAccessPolicy: Sendable, Codable, Hashable {
    public var allowedSchemes: Set<String>
    public var allowedPorts: Set<Int>
    public var allowedHosts: Set<String>
    public var blockedHosts: Set<String>
    public var allowedContentTypes: Set<String>
    public var allowPrivateNetworks: Bool
    public var maxRedirectCount: Int
    public var maxResultCount: Int
    public var maxFetchedBytes: Int
    public var maxFetchedCharacters: Int

    public init(
        allowedSchemes: Set<String> = ["https"],
        allowedPorts: Set<Int> = [443],
        allowedHosts: Set<String> = [],
        blockedHosts: Set<String> = [],
        allowedContentTypes: Set<String> = [
            "application/json",
            "text/html",
            "text/plain"
        ],
        allowPrivateNetworks: Bool = false,
        maxRedirectCount: Int = 3,
        maxResultCount: Int = 8,
        maxFetchedBytes: Int = 500_000,
        maxFetchedCharacters: Int = 12_000
    ) {
        self.allowedSchemes = allowedSchemes
        self.allowedPorts = allowedPorts
        self.allowedHosts = allowedHosts
        self.blockedHosts = blockedHosts
        self.allowedContentTypes = allowedContentTypes
        self.allowPrivateNetworks = allowPrivateNetworks
        self.maxRedirectCount = max(0, maxRedirectCount)
        self.maxResultCount = max(1, maxResultCount)
        self.maxFetchedBytes = max(1, maxFetchedBytes)
        self.maxFetchedCharacters = max(1, maxFetchedCharacters)
    }

    public static let `default` = Self()

    public func normalizedResultLimit(
        _ requested: Int?
    ) -> Int {
        let value = requested ?? maxResultCount
        return min(max(1, value), maxResultCount)
    }

    public func normalizedCharacterLimit(
        _ requested: Int?
    ) -> Int {
        let value = requested ?? maxFetchedCharacters
        return min(max(1, value), maxFetchedCharacters)
    }

    public func allows(
        urlString: String
    ) -> Bool {
        (try? validate(urlString: urlString)) != nil
    }

    public func allows(
        contentType rawValue: String?
    ) -> Bool {
        guard let normalized = normalizedContentType(
            rawValue
        ) else {
            return false
        }

        return allowedContentTypes.contains(
            normalized
        )
    }

    public func normalizedContentType(
        _ rawValue: String?
    ) -> String? {
        guard let rawValue else {
            return nil
        }

        return rawValue
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
    }

    public func validate(
        urlString: String
    ) throws -> URL {
        guard let components = URLComponents(string: urlString),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ),
              !host.isEmpty,
              let url = components.url else {
            throw WebToolError.invalidURL(urlString)
        }

        let origin = try parsedOrigin(
            scheme: scheme,
            host: host,
            port: components.port,
            originalURLString: urlString
        )

        guard allowedSchemes.contains(origin.scheme.rawValue) else {
            throw WebToolError.unsupportedScheme(
                origin.scheme.rawValue
            )
        }

        let effectivePort = origin.effectivePort
        guard allowedPorts.contains(effectivePort) else {
            throw WebToolError.disallowedPort(
                effectivePort
            )
        }

        let blockedRules = try configuredRules(
            from: blockedHosts
        )
        guard !matchesAny(
            host: origin.host,
            rules: blockedRules
        ) else {
            throw WebToolError.disallowedHost(
                origin.host
            )
        }

        let allowedRules = try configuredRules(
            from: allowedHosts
        )
        if !allowedRules.isEmpty,
           !matchesAny(
               host: origin.host,
               rules: allowedRules
           ) {
            throw WebToolError.disallowedHost(
                origin.host
            )
        }

        if !allowPrivateNetworks,
           isPrivateOrLocal(host: origin.host) {
            throw WebToolError.privateNetworkHost(
                origin.host
            )
        }

        return url
    }
}

private enum ConfiguredHostRule: Sendable, Hashable {
    case domain(Prebuilt.DomainName)
    case exact(String)
}

private extension WebAccessPolicy {
    func parsedOrigin(
        scheme: String,
        host: String,
        port: Int?,
        originalURLString: String
    ) throws -> Prebuilt.Origin {
        let renderedHost: String
        if host.contains(":"),
           !(host.hasPrefix("[") && host.hasSuffix("]")) {
            renderedHost = "[\(host)]"
        } else {
            renderedHost = host
        }

        let originString: String
        if let port {
            originString = "\(scheme)://\(renderedHost):\(port)"
        } else {
            originString = "\(scheme)://\(renderedHost)"
        }

        do {
            return try Prebuilt.OriginParser.parse(
                originString
            )
        } catch {
            throw WebToolError.invalidURL(
                originalURLString
            )
        }
    }

    func configuredRules(
        from hosts: Set<String>
    ) throws -> [ConfiguredHostRule] {
        try hosts.map(parseConfiguredHostRule)
    }

    func parseConfiguredHostRule(
        _ rawValue: String
    ) throws -> ConfiguredHostRule {
        let trimmed = rawValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            throw WebToolError.invalidConfiguredHostRule(
                rawValue
            )
        }

        let normalizedHost = try normalizedConfiguredHost(
            trimmed
        )

        if normalizedHost == "localhost"
            || isIPv4Literal(normalizedHost)
            || normalizedHost.contains(":") {
            return .exact(normalizedHost)
        }

        do {
            return .domain(
                try Prebuilt.DomainName(
                    normalizedHost
                )
            )
        } catch {
            throw WebToolError.invalidConfiguredHostRule(
                rawValue
            )
        }
    }

    func normalizedConfiguredHost(
        _ rawValue: String
    ) throws -> String {
        if let origin = tryParseOriginHost(
            rawValue
        ) {
            return origin.host
        }

        if rawValue.contains(":"),
           !rawValue.contains("["),
           !rawValue.contains("]"),
           let origin = tryParseOriginHost(
               "[\(rawValue)]"
           ) {
            return origin.host
        }

        throw WebToolError.invalidConfiguredHostRule(
            rawValue
        )
    }

    func tryParseOriginHost(
        _ host: String
    ) -> Prebuilt.Origin? {
        try? Prebuilt.OriginParser.parse(
            "https://\(host)"
        )
    }

    func matchesAny(
        host: String,
        rules: [ConfiguredHostRule]
    ) -> Bool {
        rules.contains { rule in
            ruleMatches(host: host, rule: rule)
        }
    }

    func ruleMatches(
        host: String,
        rule: ConfiguredHostRule
    ) -> Bool {
        switch rule {
        case .exact(let expected):
            return host == expected

        case .domain(let domain):
            return host == domain.rawValue
                || host.hasSuffix(".\(domain.rawValue)")
        }
    }

    func isIPv4Literal(
        _ host: String
    ) -> Bool {
        let octets = host.split(separator: ".")
        guard octets.count == 4 else {
            return false
        }

        return octets.allSatisfy { part in
            guard let value = Int(part),
                  (0...255).contains(value) else {
                return false
            }

            return !part.isEmpty
        }
    }

    func isPrivateOrLocal(
        host: String
    ) -> Bool {
        if host == "localhost"
            || host == "0.0.0.0"
            || host == "::1" {
            return true
        }

        if host.hasSuffix(".local") {
            return true
        }

        if host.hasPrefix("fe80:") {
            return true
        }

        let octets = host.split(separator: ".").compactMap {
            Int($0)
        }

        guard octets.count == 4 else {
            return false
        }

        let a = octets[0]
        let b = octets[1]

        if a == 10 || a == 127 {
            return true
        }

        if a == 169 && b == 254 {
            return true
        }

        if a == 192 && b == 168 {
            return true
        }

        if a == 172 && (16...31).contains(b) {
            return true
        }

        return false
    }
}
