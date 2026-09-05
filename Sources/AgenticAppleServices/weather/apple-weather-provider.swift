public struct WeatherCoordinate:
    Sendable,
    Codable,
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

public struct CurrentWeatherSnapshot:
    Sendable,
    Codable,
    Hashable
{
    public let coordinate: WeatherCoordinate
    public let date: String
    public let condition: String
    public let symbolName: String
    public let temperatureCelsius: Double
    public let apparentTemperatureCelsius: Double
    public let humidity: Double
    public let windSpeedMetersPerSecond: Double

    public init(
        coordinate: WeatherCoordinate,
        date: String,
        condition: String,
        symbolName: String,
        temperatureCelsius: Double,
        apparentTemperatureCelsius: Double,
        humidity: Double,
        windSpeedMetersPerSecond: Double
    ) {
        self.coordinate = coordinate
        self.date = date
        self.condition = condition
        self.symbolName = symbolName
        self.temperatureCelsius = temperatureCelsius
        self.apparentTemperatureCelsius = apparentTemperatureCelsius
        self.humidity = humidity
        self.windSpeedMetersPerSecond = windSpeedMetersPerSecond
    }
}

public struct HourlyWeatherSnapshot:
    Sendable,
    Codable,
    Hashable
{
    public let date: String
    public let condition: String
    public let symbolName: String
    public let temperatureCelsius: Double
    public let precipitationChance: Double

    public init(
        date: String,
        condition: String,
        symbolName: String,
        temperatureCelsius: Double,
        precipitationChance: Double
    ) {
        self.date = date
        self.condition = condition
        self.symbolName = symbolName
        self.temperatureCelsius = temperatureCelsius
        self.precipitationChance = precipitationChance
    }
}

public struct DailyWeatherSnapshot:
    Sendable,
    Codable,
    Hashable
{
    public let date: String
    public let condition: String
    public let symbolName: String
    public let lowTemperatureCelsius: Double
    public let highTemperatureCelsius: Double
    public let precipitationChance: Double

    public init(
        date: String,
        condition: String,
        symbolName: String,
        lowTemperatureCelsius: Double,
        highTemperatureCelsius: Double,
        precipitationChance: Double
    ) {
        self.date = date
        self.condition = condition
        self.symbolName = symbolName
        self.lowTemperatureCelsius = lowTemperatureCelsius
        self.highTemperatureCelsius = highTemperatureCelsius
        self.precipitationChance = precipitationChance
    }
}

public struct WeatherForecastSnapshot:
    Sendable,
    Codable,
    Hashable
{
    public let coordinate: WeatherCoordinate
    public let hourly: [HourlyWeatherSnapshot]
    public let daily: [DailyWeatherSnapshot]

    public init(
        coordinate: WeatherCoordinate,
        hourly: [HourlyWeatherSnapshot],
        daily: [DailyWeatherSnapshot]
    ) {
        self.coordinate = coordinate
        self.hourly = hourly
        self.daily = daily
    }
}

public protocol AppleWeatherProvider: Sendable {
    func currentWeather(
        at coordinate: WeatherCoordinate
    ) async throws -> CurrentWeatherSnapshot

    func forecast(
        at coordinate: WeatherCoordinate,
        hours: Int,
        days: Int
    ) async throws -> WeatherForecastSnapshot
}
