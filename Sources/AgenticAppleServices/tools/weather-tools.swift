import Agentic
import AgenticExecution
import Schema
import SchemaMacros

@JSONSchema
public struct WeatherCurrentToolInput:
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

@JSONSchema
public struct WeatherForecastToolInput:
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

public struct WeatherCurrentTool:
    AgentTool
{
    public typealias Input = WeatherCurrentToolInput
    public typealias Output = CurrentWeatherSnapshot

    public let identifier: AgentToolIdentifier =
        "weather_current"
    public let description =
        "Read current WeatherKit conditions for an explicit latitude and longitude without requesting device location."
    public let risk: ActionRisk = .observe

    private let provider: any AppleWeatherProvider

    public init(
        provider: any AppleWeatherProvider
    ) {
        self.provider = provider
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        _ = context

        return try await provider.currentWeather(
            at: .init(
                latitude: input.latitude,
                longitude: input.longitude
            )
        )
    }
}

public struct WeatherForecastTool:
    AgentTool
{
    public typealias Input = WeatherForecastToolInput
    public typealias Output = WeatherForecastSnapshot

    public let identifier: AgentToolIdentifier =
        "weather_forecast"
    public let description =
        "Read bounded hourly and daily WeatherKit forecasts for an explicit latitude and longitude without requesting device location."
    public let risk: ActionRisk = .observe

    private let provider: any AppleWeatherProvider

    public init(
        provider: any AppleWeatherProvider
    ) {
        self.provider = provider
    }

    public func call(
        _ input: Input,
        context: AgentToolExecutionContext
    ) async throws -> Output {
        _ = context

        return try await provider.forecast(
            at: .init(
                latitude: input.latitude,
                longitude: input.longitude
            ),
            hours: input.hours,
            days: input.days
        )
    }
}
