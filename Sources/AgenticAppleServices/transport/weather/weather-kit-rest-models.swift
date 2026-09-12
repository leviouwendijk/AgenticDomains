struct WeatherKitRESTResponse: Decodable {
    let currentWeather: WeatherKitRESTCurrentWeather?
    let forecastHourly: WeatherKitRESTHourlyForecast?
    let forecastDaily: WeatherKitRESTDailyForecast?
}

struct WeatherKitRESTCurrentWeather: Decodable {
    let asOf: String
    let conditionCode: String
    let temperature: Double
    let temperatureApparent: Double
    let humidity: Double
    let windSpeed: Double
}

struct WeatherKitRESTHourlyForecast: Decodable {
    let hours: [WeatherKitRESTHour]
}

struct WeatherKitRESTHour: Decodable {
    let forecastStart: String
    let conditionCode: String
    let temperature: Double
    let precipitationChance: Double
}

struct WeatherKitRESTDailyForecast: Decodable {
    let days: [WeatherKitRESTDay]
}

struct WeatherKitRESTDay: Decodable {
    let forecastStart: String
    let conditionCode: String
    let temperatureMin: Double
    let temperatureMax: Double
    let precipitationChance: Double
}
