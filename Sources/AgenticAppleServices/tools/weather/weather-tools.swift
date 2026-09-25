import Agentic
import Macros
import Schema
import Workspace

public extension AppleServices.Tools {
    @Tool("weather_current")
    struct ReadCurrentWeather {
        @JSONSchema
        public struct Input:
            Codable,
            Sendable,
            Hashable
        {
            public let latitude: Double
            public let longitude: Double

            public init(
                latitude: Double,
                longitude: Double
            ) {
                self.latitude = latitude
                self.longitude = longitude
            }
        }

        public typealias Output = CurrentWeatherSnapshot

        public static let purpose =
            "Read current WeatherKit conditions for an explicit latitude and longitude without requesting device location."
        public static let risk: ActionRisk = .observe

        private let provider: any AppleWeatherProvider

        public init(
            provider: any AppleWeatherProvider
        ) {
            self.provider = provider
        }

        public func call(
            _ input: Input,
            workspace _: WorkspaceContext?
        ) async throws -> Output {
            try await provider.currentWeather(
                at: .init(
                    latitude: input.latitude,
                    longitude: input.longitude
                )
            )
        }
    }

    @Tool("weather_forecast")
    struct ReadWeatherForecast {
        @JSONSchema
        public struct Input:
            Codable,
            Sendable,
            Hashable
        {
            public let latitude: Double
            public let longitude: Double

            /// Number of hourly forecast entries to return. WeatherKit currently supplies up to 25 contiguous hours for the default hourly query.
            public let hours: Int

            /// Number of daily forecast entries to return. WeatherKit currently supplies up to 10 contiguous days for the default daily query.
            public let days: Int

            public init(
                latitude: Double,
                longitude: Double,
                hours: Int,
                days: Int
            ) {
                self.latitude = latitude
                self.longitude = longitude
                self.hours = hours
                self.days = days
            }
        }

        public typealias Output = WeatherForecastSnapshot

        public static let purpose =
            "Read bounded hourly and daily WeatherKit forecasts for an explicit latitude and longitude without requesting device location."
        public static let risk: ActionRisk = .observe

        private let provider: any AppleWeatherProvider

        public init(
            provider: any AppleWeatherProvider
        ) {
            self.provider = provider
        }

        public func call(
            _ input: Input,
            workspace _: WorkspaceContext?
        ) async throws -> Output {
            try await provider.forecast(
                at: .init(
                    latitude: input.latitude,
                    longitude: input.longitude
                ),
                hours: input.hours,
                days: input.days
            )
        }
    }
}
