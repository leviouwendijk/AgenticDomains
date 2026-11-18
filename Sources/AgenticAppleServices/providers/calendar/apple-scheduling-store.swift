import AgenticConfiguration
import AgenticScheduling
import Foundation

public extension Scheduling.ConfigurationStore {
    /// Scheduling on a Mac: the home's `domains/scheduling.frame` over
    /// Apple Calendar, with addresses and travel times from Apple Maps.
    /// Resolved places are cached in the home.
    static func apple(
        home: AgentHome = AgentHomeLocator().resolveHome()
    ) -> Self {
        let sources: [any CalendarSource] = [EventKitCalendarSource()]
        let places = home.layout.runtimeStorage.cachedir
            .appendingPathComponent("scheduling-places.json")
        return .init(home: home, sources: sources) { configuration in
            configuration.runtime(
                sources: sources,
                resolver: MapKitPlaceResolver(cacheFile: places),
                travel: MapKitTravelEstimator()
            )
        }
    }
}
