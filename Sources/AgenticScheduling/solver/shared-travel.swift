import Foundation
import Macros
import Schema

/// What splitting a shared trip means for scheduling.
@JSONSchema
public enum SplitTravelPolicy:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    /// A placement that splits a shared trip is excluded unless the request
    /// allows it: a second vehicle is an escalation.
    case avoid
    /// Splitting only lowers the score.
    case warn
}

/// Shared trips on one day: participants who travel together to an
/// appointment must come from the same place and leave for the same place.
/// Home counts as one place, since one vehicle can drop everyone off.
struct SharedTravel {
    struct Item: Sendable, Hashable {
        let key: String
        let title: String
        let interval: ScheduleInterval
        let shared: Bool
        let event: ScheduledEvent?
    }

    struct Split: Sendable {
        let trip: Item
        /// True when they arrive separately, false when they leave separately.
        let arriving: Bool
        /// Each traveller's stop before or after the trip; `nil` is home.
        let stops: [(participant: String, stop: Item?)]

        var involves: Set<String> {
            Set([trip.key] + stops.compactMap { $0.stop?.key })
        }

        var description: String {
            let direction = arriving ? "before" : "after"
            let routes = stops.map { "\($0.participant) \(arriving ? "from" : "to") \($0.stop.map { "'\($0.title)'" } ?? "home")" }
            return "\(direction) '\(trip.title)': \(routes.joined(separator: ", "))"
        }

        /// The first stop that is an appointment, for reporting.
        var diverging: (participant: String, stop: Item)? {
            stops.lazy.compactMap { entry in entry.stop.map { (entry.participant, $0) } }.first
        }
    }

    static func key(_ event: ScheduledEvent) -> String {
        "\(event.source)|\(event.identifier)|\(event.interval.start.timeIntervalSince1970)"
    }

    /// Timed blocking commitments, as trip items.
    static func items(_ timeline: ParticipantTimeline) -> [Item] {
        timeline.blocking
            .filter { !$0.isAllDay }
            .map { .init(key: key($0), title: $0.title, interval: $0.interval, shared: timeline.sharedTravel.contains($0), event: $0) }
    }

    /// Every split among the participants' shared trips.
    static func splits(
        _ items: [String: [Item]],
        zones: [String: ScheduleTimeZone]
    ) -> [Split] {
        var owners: [String: (item: Item, participants: [String])] = [:]
        for (participant, list) in items {
            for item in list where item.shared {
                owners[item.key, default: (item, [])].participants.append(participant)
            }
        }

        var splits: [Split] = []
        for (_, trip) in owners.sorted(by: { $0.value.item.interval.start < $1.value.item.interval.start })
        where trip.participants.count > 1 {
            let travellers = trip.participants.sorted()
            for arriving in [true, false] {
                let stops: [(participant: String, stop: Item?)] = travellers.map { participant in
                    let zone = zones[participant] ?? .current()
                    let list = items[participant] ?? []
                    let stop = arriving
                        ? list
                            .filter { $0.interval.end <= trip.item.interval.start && zone.sameDay($0.interval.end, trip.item.interval.start) }
                            .max { $0.interval.end < $1.interval.end }
                        : list
                            .filter { $0.interval.start >= trip.item.interval.end && zone.sameDay(trip.item.interval.end, $0.interval.start) }
                            .min { $0.interval.start < $1.interval.start }
                    return (participant, stop)
                }
                if Set(stops.map { $0.stop?.key }).count > 1 {
                    splits.append(.init(trip: trip.item, arriving: arriving, stops: stops))
                }
            }
        }
        return splits
    }
}
