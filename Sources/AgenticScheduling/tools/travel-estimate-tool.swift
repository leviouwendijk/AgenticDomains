import Agentic
import Foundation
import Macros
import Schema

public extension Scheduling.Tools {
    @Tool("travel_estimate")
    struct EstimateTravel {
        @JSONSchema
        public struct Input: HashableSource {
            /// Origin as location text, as written in a calendar event.
            public let origin: String
            /// Destination as location text.
            public let destination: String
            /// Defaults to the configured mode.
            public let travel_mode: TravelMode?
            /// Departure, ISO 8601 with offset. Defaults to now; only routed
            /// estimators use it.
            public let departing: String?

            public init(origin: String, destination: String, travel_mode: TravelMode? = nil, departing: String? = nil) {
                self.origin = origin
                self.destination = destination
                self.travel_mode = travel_mode
                self.departing = departing
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let origin: SchedulingPlace?
            public let destination: SchedulingPlace?
            /// Absent when either end does not resolve.
            public let estimate: TravelEstimate?
            public let information_gaps: [String]
        }

        public static let purpose =
            "Estimate travel time between two locations, stating how it was estimated. Locations that do not resolve are reported, never guessed."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: CapabilityContext) async throws -> Output {
            let runtime = try Scheduling.runtime(in: context)
            let departing = try input.departing.map { try ScheduleTimestamp.parse($0, field: "departing") } ?? Date()
            let oracle = TravelOracle(
                resolver: runtime.places,
                estimator: runtime.travel,
                mode: input.travel_mode ?? runtime.defaults.travelMode
            )
            var origin: SchedulingPlace?
            if case .resolved(let place) = await oracle.place(input.origin) {
                origin = place
            }
            var destination: SchedulingPlace?
            if case .resolved(let place) = await oracle.place(input.destination) {
                destination = place
            }
            var estimate: TravelEstimate?
            if let origin, let destination {
                estimate = await oracle.estimate(from: origin, to: destination, departing: departing)
            }
            return .init(origin: origin, destination: destination, estimate: estimate, information_gaps: await oracle.gaps)
        }
    }
}
