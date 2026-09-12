import Foundation

public actor WeatherKitRESTProvider:
    AppleWeatherProvider
{
    private let explicitConfiguration:
        WeatherKitRESTConfiguration?
    private let session: URLSession

    private var resolvedConfiguration:
        WeatherKitRESTConfiguration?
    private var cachedToken:
        WeatherKitRESTDeveloperToken?

    public init(
        configuration: WeatherKitRESTConfiguration? = nil,
        session: URLSession = .shared
    ) {
        self.explicitConfiguration = configuration
        self.session = session
    }

    public func currentWeather(
        at coordinate: WeatherCoordinate
    ) async throws -> CurrentWeatherSnapshot {
        let response = try await request(
            coordinate: coordinate,
            dataSets: [
                "currentWeather",
            ]
        )

        guard let current = response.currentWeather else {
            throw WeatherKitRESTProviderError
                .missingCurrentWeather
        }

        return .init(
            coordinate: coordinate,
            date: current.asOf,
            conditionCode: current.conditionCode,
            symbolName: nil,
            temperatureCelsius:
                current.temperature,
            apparentTemperatureCelsius:
                current.temperatureApparent,
            humidity: current.humidity,
            windSpeedMetersPerSecond:
                current.windSpeed / 3.6
        )
    }

    public func forecast(
        at coordinate: WeatherCoordinate,
        hours: Int,
        days: Int
    ) async throws -> WeatherForecastSnapshot {
        let response = try await request(
            coordinate: coordinate,
            dataSets: [
                "forecastHourly",
                "forecastDaily",
            ]
        )

        guard let hourly = response.forecastHourly else {
            throw WeatherKitRESTProviderError
                .missingHourlyForecast
        }

        guard let daily = response.forecastDaily else {
            throw WeatherKitRESTProviderError
                .missingDailyForecast
        }

        let hourLimit = min(
            max(hours, 1),
            25
        )
        let dayLimit = min(
            max(days, 1),
            10
        )

        return .init(
            coordinate: coordinate,
            hourly: Array(
                hourly.hours
                    .prefix(hourLimit)
                    .map { hour in
                        .init(
                            date:
                                hour.forecastStart,
                            conditionCode:
                                hour.conditionCode,
                            symbolName: nil,
                            temperatureCelsius:
                                hour.temperature,
                            precipitationChance:
                                hour.precipitationChance
                        )
                    }
            ),
            daily: Array(
                daily.days
                    .prefix(dayLimit)
                    .map { day in
                        .init(
                            date:
                                day.forecastStart,
                            conditionCode:
                                day.conditionCode,
                            symbolName: nil,
                            lowTemperatureCelsius:
                                day.temperatureMin,
                            highTemperatureCelsius:
                                day.temperatureMax,
                            precipitationChance:
                                day.precipitationChance
                        )
                    }
            )
        )
    }
}

private extension WeatherKitRESTProvider {
    func configuration()
        throws -> WeatherKitRESTConfiguration
    {
        if let resolvedConfiguration {
            return resolvedConfiguration
        }

        let configuration:
            WeatherKitRESTConfiguration

        if let explicitConfiguration {
            configuration = explicitConfiguration
        } else {
            configuration = try .environment()
        }

        resolvedConfiguration = configuration
        return configuration
    }

    func developerToken(
        configuration: WeatherKitRESTConfiguration
    ) throws -> String {
        let now = Date()

        if let cachedToken,
           cachedToken.expiresAt
            .timeIntervalSince(now) > 60
        {
            return cachedToken.value
        }

        let token = try WeatherKitRESTTokenProvider
            .token(
                configuration: configuration,
                now: now
            )

        cachedToken = token
        return token.value
    }

    func request(
        coordinate: WeatherCoordinate,
        dataSets: [String]
    ) async throws -> WeatherKitRESTResponse {
        try Self.validate(
            coordinate
        )

        let configuration = try configuration()
        let token = try developerToken(
            configuration: configuration
        )

        var components = URLComponents()
        components.scheme = "https"
        components.host = "weatherkit.apple.com"
        components.path =
            "/api/v1/weather/"
            + configuration.language
            + "/"
            + String(coordinate.latitude)
            + "/"
            + String(coordinate.longitude)
        components.queryItems = [
            .init(
                name: "dataSets",
                value: dataSets.joined(
                    separator: ","
                )
            ),
            .init(
                name: "timezone",
                value: configuration.timeZone
            ),
        ]

        guard let url = components.url else {
            throw WeatherKitRESTProviderError
                .invalidRequestURL
        }

        var request = URLRequest(
            url: url
        )
        request.httpMethod = "GET"
        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(
            for: request
        )

        guard let response = response
            as? HTTPURLResponse
        else {
            throw WeatherKitRESTProviderError
                .invalidHTTPResponse
        }

        guard response.statusCode == 200 else {
            let body = String(
                data: data,
                encoding: .utf8
            ) ?? "<non-UTF8 response>"

            throw WeatherKitRESTProviderError
                .httpStatus(
                    response.statusCode,
                    body
                )
        }

        return try JSONDecoder().decode(
            WeatherKitRESTResponse.self,
            from: data
        )
    }

    static func validate(
        _ coordinate: WeatherCoordinate
    ) throws {
        guard (-90.0 ... 90.0).contains(
            coordinate.latitude
        ) else {
            throw WeatherKitRESTProviderError
                .invalidLatitude(
                    coordinate.latitude
                )
        }

        guard (-180.0 ... 180.0).contains(
            coordinate.longitude
        ) else {
            throw WeatherKitRESTProviderError
                .invalidLongitude(
                    coordinate.longitude
                )
        }
    }
}

public enum WeatherKitRESTProviderError:
    Error,
    Sendable,
    LocalizedError
{
    case invalidLatitude(Double)
    case invalidLongitude(Double)
    case invalidRequestURL
    case invalidHTTPResponse
    case httpStatus(Int, String)
    case missingCurrentWeather
    case missingHourlyForecast
    case missingDailyForecast

    public var errorDescription: String? {
        switch self {
        case .invalidLatitude(let latitude):
            return "Weather latitude must be between -90 and 90 degrees; received \(latitude)."

        case .invalidLongitude(let longitude):
            return "Weather longitude must be between -180 and 180 degrees; received \(longitude)."

        case .invalidRequestURL:
            return "Unable to construct the WeatherKit REST request URL."

        case .invalidHTTPResponse:
            return "WeatherKit REST returned a non-HTTP response."

        case .httpStatus(let status, let body):
            return "WeatherKit REST returned HTTP \(status): \(body)"

        case .missingCurrentWeather:
            return "WeatherKit REST response did not contain currentWeather."

        case .missingHourlyForecast:
            return "WeatherKit REST response did not contain forecastHourly."

        case .missingDailyForecast:
            return "WeatherKit REST response did not contain forecastDaily."
        }
    }
}
