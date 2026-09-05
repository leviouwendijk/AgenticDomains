import CoreLocation
import Foundation
import WeatherKit

public actor WeatherKitWeatherProvider:
    AppleWeatherProvider
{
    public init() {}

    public func currentWeather(
        at coordinate: WeatherCoordinate
    ) async throws -> CurrentWeatherSnapshot {
        let location = try Self.location(
            from: coordinate
        )
        let current = try await WeatherService.shared
            .weather(
                for: location,
                including: .current
            )

        return .init(
            coordinate: coordinate,
            date: Self.string(
                current.date
            ),
            condition: current.condition.description,
            symbolName: current.symbolName,
            temperatureCelsius:
                current.temperature
                    .converted(to: .celsius)
                    .value,
            apparentTemperatureCelsius:
                current.apparentTemperature
                    .converted(to: .celsius)
                    .value,
            humidity: current.humidity,
            windSpeedMetersPerSecond:
                current.wind.speed
                    .converted(to: .metersPerSecond)
                    .value
        )
    }

    public func forecast(
        at coordinate: WeatherCoordinate,
        hours: Int,
        days: Int
    ) async throws -> WeatherForecastSnapshot {
        let location = try Self.location(
            from: coordinate
        )
        let (hourly, daily) = try await
            WeatherService.shared.weather(
                for: location,
                including: .hourly,
                .daily
            )

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
                hourly.forecast
                    .prefix(hourLimit)
                    .map { hour in
                        .init(
                            date: Self.string(
                                hour.date
                            ),
                            condition:
                                hour.condition.description,
                            symbolName:
                                hour.symbolName,
                            temperatureCelsius:
                                hour.temperature
                                    .converted(
                                        to: .celsius
                                    )
                                    .value,
                            precipitationChance:
                                hour.precipitationChance
                        )
                    }
            ),
            daily: Array(
                daily.forecast
                    .prefix(dayLimit)
                    .map { day in
                        .init(
                            date: Self.string(
                                day.date
                            ),
                            condition:
                                day.condition.description,
                            symbolName:
                                day.symbolName,
                            lowTemperatureCelsius:
                                day.lowTemperature
                                    .converted(
                                        to: .celsius
                                    )
                                    .value,
                            highTemperatureCelsius:
                                day.highTemperature
                                    .converted(
                                        to: .celsius
                                    )
                                    .value,
                            precipitationChance:
                                day.precipitationChance
                        )
                    }
            )
        )
    }
}

private extension WeatherKitWeatherProvider {
    static func location(
        from coordinate: WeatherCoordinate
    ) throws -> CLLocation {
        guard (-90.0 ... 90.0).contains(
            coordinate.latitude
        ) else {
            throw WeatherKitWeatherProviderError
                .invalidLatitude(
                    coordinate.latitude
                )
        }

        guard (-180.0 ... 180.0).contains(
            coordinate.longitude
        ) else {
            throw WeatherKitWeatherProviderError
                .invalidLongitude(
                    coordinate.longitude
                )
        }

        return CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    static func string(
        _ date: Date
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(
            .withFractionalSeconds
        )
        return formatter.string(
            from: date
        )
    }
}

public enum WeatherKitWeatherProviderError:
    Error,
    Sendable,
    LocalizedError
{
    case invalidLatitude(Double)
    case invalidLongitude(Double)

    public var errorDescription: String? {
        switch self {
        case .invalidLatitude(let latitude):
            return "Weather latitude must be between -90 and 90 degrees; received \(latitude)."

        case .invalidLongitude(let longitude):
            return "Weather longitude must be between -180 and 180 degrees; received \(longitude)."
        }
    }
}
