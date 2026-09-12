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
