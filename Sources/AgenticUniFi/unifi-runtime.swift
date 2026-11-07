import Difference
import Errors
import Foundation
import Macros
import Schema
import UniFiPlanning

public extension UniFi {
    /// Restrictive display projection: no IP, CIDR, MAC, URL or dotted host text.
    /// Safe character classes cannot detect semantic secrets in otherwise ordinary names.
    fileprivate static func display_label(_ name: String, fallback: String) -> String {
        let bytes = Array(name.utf8)
        guard !bytes.isEmpty, bytes.count <= 64,
              bytes.allSatisfy({ value in
                  (65...90).contains(Int(value)) ||
                  (97...122).contains(Int(value)) ||
                  (48...57).contains(Int(value)) ||
                  value == 32 || value == 45 || value == 95
              }),
              name.trimmingCharacters(in: .whitespaces).count > 0
        else { return fallback }
        return name
    }

    fileprivate static func safe_enum(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty, raw.utf8.count <= 48,
              raw.utf8.allSatisfy({ byte in
                  (65...90).contains(Int(byte)) ||
                  (97...122).contains(Int(byte)) ||
                  (48...57).contains(Int(byte)) || byte == 95
              }) else { return nil }
        return raw
    }

    @JSONSchema
    struct SiteReference: Sendable, Codable, Hashable {
        public let site_id: UUID
        public let ordinal: Int

        public init(site_id: UUID, ordinal: Int) {
            self.site_id = site_id
            self.ordinal = ordinal
        }
    }

    @JSONSchema
    struct SiteDirectory: Sendable, Codable, Hashable {
        public let sites: [SiteReference]

        public init(sites: [SiteReference]) {
            self.sites = sites
        }
    }

    @JSONSchema
    struct Network: Sendable, Codable, Hashable {
        public let id: UUID
        public let label: String
        public let vlan_id: Int
        public let enabled: Bool
        public let zone_id: UUID?
    }

    @JSONSchema
    struct Zone: Sendable, Codable, Hashable {
        public let id: UUID
        public let label: String
        public let network_ids: [UUID]
        public let user_defined: Bool
    }

    @JSONSchema
    struct Policy: Sendable, Codable, Hashable {
        public let id: UUID
        public let label: String
        public let source_zone_label: String
        public let destination_zone_label: String
        public let index: Int
        public let enabled: Bool
        public let logging_enabled: Bool
        public let report_flow_enabled: Bool?
        public let action: String
        public let source_zone_id: UUID
        public let destination_zone_id: UUID
        public let user_defined: Bool
    }

    @JSONSchema
    struct Inventory: Sendable, Codable, Hashable {
        public let snapshot_id: UUID
        public let site_id: UUID
        public let networks: [Network]
        public let zones: [Zone]
        public let policies: [Policy]
        public let reference_complete: Bool
        public let unresolved_network_reference_count: Int
        public let unresolved_zone_reference_count: Int

        init(snapshot_id: UUID, snapshot: UniFiPlanning.Snapshot) {
            self.snapshot_id = snapshot_id
            site_id = snapshot.site_id
            reference_complete = snapshot.reference_complete
            unresolved_network_reference_count = snapshot.unresolved_network_ids.count
            unresolved_zone_reference_count = snapshot.unresolved_zone_ids.count
            networks = snapshot.networks.map { network in
                .init(
                    id: network.id,
                    label: UniFi.display_label(network.name, fallback: "VLAN \(network.vlan_id)"),
                    vlan_id: network.vlan_id,
                    enabled: network.enabled,
                    zone_id: network.zone_id
                )
            }
            zones = snapshot.zones.map { zone in
                .init(
                    id: zone.id,
                    label: UniFi.display_label(zone.name, fallback: "Zone \(zone.id.uuidString.prefix(8))"),
                    network_ids: zone.network_ids,
                    user_defined: zone.origin == "USER_DEFINED"
                )
            }
            policies = snapshot.policies.map { policy in
                let action: String
                switch policy.action.uppercased() {
                case "ALLOW", "BLOCK", "REJECT":
                    action = policy.action.uppercased()
                default:
                    action = "UNKNOWN"
                }
                return .init(
                    id: policy.id,
                    label: UniFi.display_label(policy.name, fallback: "Policy \(policy.index)"),
                    source_zone_label: snapshot.zones.first(where: { $0.id == policy.source_zone_id }).map {
                        UniFi.display_label($0.name, fallback: "Zone \($0.id.uuidString.prefix(8))")
                    } ?? "Unresolved zone",
                    destination_zone_label: snapshot.zones.first(where: { $0.id == policy.destination_zone_id }).map {
                        UniFi.display_label($0.name, fallback: "Zone \($0.id.uuidString.prefix(8))")
                    } ?? "Unresolved zone",
                    index: policy.index,
                    enabled: policy.enabled,
                    logging_enabled: policy.logging_enabled,
                    report_flow_enabled: policy.report_flow_enabled,
                    action: action,
                    source_zone_id: policy.source_zone_id,
                    destination_zone_id: policy.destination_zone_id,
                    user_defined: policy.origin == "USER_DEFINED"
                )
            }
        }
    }

    @JSONSchema
    struct NetworkList: Sendable, Codable, Hashable {
        public let networks: [Network]
    }

    @JSONSchema
    struct ZoneList: Sendable, Codable, Hashable {
        public let zones: [Zone]
    }

    @JSONSchema
    struct NetworkDetail: Sendable, Codable, Hashable {
        public let network: Network
        public let zones: [Zone]
        public let policy_count_for_zones: Int
    }

    @JSONSchema
    struct PolicyPage: Sendable, Codable, Hashable {
        public let total_count: Int
        public let offset: Int
        public let policies: [Policy]
    }

    @JSONSchema
    struct PolicyQuery: Sendable, Codable, Hashable {
        public let snapshot_id: UUID
        public let zone_id: UUID?
        public let enabled: Bool?
        public let action: String?
        public let offset: Int?
        public let limit: Int?

        public init(
            snapshot_id: UUID,
            zone_id: UUID? = nil,
            enabled: Bool? = nil,
            action: String? = nil,
            offset: Int? = nil,
            limit: Int? = nil
        ) {
            self.snapshot_id = snapshot_id
            self.zone_id = zone_id
            self.enabled = enabled
            self.action = action
            self.offset = offset
            self.limit = limit
        }
    }

    @JSONSchema
    struct PortMatch: Sendable, Codable, Hashable {
        public let type: String
        public let value: Int?
        public let start: Int?
        public let stop: Int?
    }

    @JSONSchema
    struct PortSelection: Sendable, Codable, Hashable {
        public let type: String
        public let match_opposite: Bool?
        public let items: [PortMatch]?
        public let traffic_matching_list_id: UUID?
    }

    @JSONSchema
    struct TrafficSelection: Sendable, Codable, Hashable {
        public let type: String
        public let network_ids: [UUID]?
        public let network_match_opposite: Bool?
        public let ports: PortSelection?
        public let other_filter_details_unavailable: Bool
    }

    @JSONSchema
    struct ProtocolSelection: Sendable, Codable, Hashable {
        public let type: String
        public let match_opposite: Bool?
        public let name: String?
        public let preset: String?
        public let number: Int?
    }

    @JSONSchema
    struct PolicyDetail: Sendable, Codable, Hashable {
        public let policy: Policy
        public let source: TrafficSelection?
        public let destination: TrafficSelection?
        public let protocol_selection: ProtocolSelection?
        public let ip_version: String
        public let return_traffic: Bool?
        public let connection_states: [String]?
        public let ipsec_filter: String?
        public let schedule: String?
        public let raw_addresses_and_descriptions_omitted: Bool
    }

    @JSONSchema
    struct TrafficPathQuery: Sendable, Codable, Hashable {
        public let snapshot_id: UUID
        public let source_network_id: UUID
        public let destination_network_id: UUID
    }

    @JSONSchema
    struct TrafficPathInspection: Sendable, Codable, Hashable {
        public let source_network: Network
        public let destination_network: Network
        public let source_zone: Zone
        public let destination_zone: Zone
        public let candidate_policies: [Policy]
        public let candidate_count: Int
        public let port_evaluated: Bool
        public let protocol_evaluated: Bool
        public let effective_behavior_verified: Bool
        public let limitation: String
    }

    @JSONSchema
    struct ZoneMembership: Sendable, Codable, Hashable {
        public let zone_id: UUID
        public let network_ids: [UUID]

        public init(zone_id: UUID, network_ids: [UUID]) {
            self.zone_id = zone_id
            self.network_ids = network_ids
        }
    }

    @JSONSchema
    struct PolicyTelemetry: Sendable, Codable, Hashable {
        public let policy_id: UUID
        public let logging_enabled: Bool?
        public let report_flow_enabled: Bool?

        public init(
            policy_id: UUID,
            logging_enabled: Bool? = nil,
            report_flow_enabled: Bool? = nil
        ) {
            self.policy_id = policy_id
            self.logging_enabled = logging_enabled
            self.report_flow_enabled = report_flow_enabled
        }
    }

    @JSONSchema
    struct PlanRequest: Sendable, Codable, Hashable {
        public let snapshot_id: UUID
        public let zone_memberships: [ZoneMembership]
        public let policy_telemetry: [PolicyTelemetry]

        public init(
            snapshot_id: UUID,
            zone_memberships: [ZoneMembership] = [],
            policy_telemetry: [PolicyTelemetry] = []
        ) {
            self.snapshot_id = snapshot_id
            self.zone_memberships = zone_memberships
            self.policy_telemetry = policy_telemetry
        }
    }

    @JSONSchema
    struct PlanPreview: Sendable, Codable, Hashable {
        public let plan_id: UUID
        public let snapshot_id: UUID
        public let site_id: UUID
        public let change_summary: String
        public let presentation: DifferencePresentation

        init(plan_id: UUID, snapshot_id: UUID, plan: UniFiPlanning.Plan) {
            self.plan_id = plan_id
            self.snapshot_id = snapshot_id
            site_id = plan.before.site_id
            change_summary = plan.presentation.changeSummary
            presentation = plan.presentation
        }
    }

    /// Session-local state. Raw controller models never enter tool results.
    actor Runtime {
        public enum Failure: Error, Sendable, LocalizedError, CustomStringConvertible {
            case site_discovery_failed(UniFiPlanning.ReadFailure)
            case capture_failed(UniFiPlanning.ReadFailure)
            case unknown_snapshot
            case unknown_network
            case unknown_policy
            case unknown_plan
            case invalid_query
            case unresolved_path
            case invalid_plan

            public var description: String {
                switch self {
                case .site_discovery_failed(let detail):
                    return "site_discovery_failed " + detail.description
                case .capture_failed(let detail):
                    return "capture_failed " + detail.description
                case .unknown_snapshot:
                    return "unknown_snapshot"
                case .unknown_network:
                    return "unknown_network"
                case .unknown_policy:
                    return "unknown_policy"
                case .unknown_plan:
                    return "unknown_plan"
                case .invalid_query:
                    return "invalid_query"
                case .unresolved_path:
                    return "unresolved_path"
                case .invalid_plan:
                    return "invalid_plan"
                }
            }

            public var errorDescription: String? { description }
        }

        private let read: @Sendable (UUID) async throws -> UniFiPlanning.Snapshot
        private let list_sites: @Sendable () async throws -> [UUID]
        private var snapshots: [UUID: UniFiPlanning.Snapshot] = [:]
        private var plans: [UUID: (snapshot_id: UUID, plan: UniFiPlanning.Plan)] = [:]

        public init(reader: UniFiPlanning.Reader) {
            read = { site_id in
                try await reader.capture(site_id: site_id)
            }
            list_sites = {
                let sites = try await reader.list_sites()
                return sites.map(\.id)
            }
        }

        /// Supports offline fixtures without a controller or credentials.
        public init(
            read: @escaping @Sendable (UUID) async throws -> UniFiPlanning.Snapshot,
            list_sites: @escaping @Sendable () async throws -> [UUID] = { [] }
        ) {
            self.read = read
            self.list_sites = list_sites
        }

        public func sites() async throws -> SiteDirectory {
            let ids: [UUID]
            do {
                ids = try await list_sites()
            } catch let error as UniFiPlanning.ReadFailure {
                throw Failure.site_discovery_failed(error)
            } catch {
                throw Failure.site_discovery_failed(
                    .init(stage: .sites, kind: .unexpected)
                )
            }
            guard Set(ids).count == ids.count else {
                throw Failure.site_discovery_failed(
                    .init(stage: .sites, kind: .inconsistent_data)
                )
            }
            return .init(sites: ids.enumerated().map { entry in
                .init(site_id: entry.element, ordinal: entry.offset + 1)
            })
        }

        public func capture(site_id: UUID) async throws -> Inventory {
            let snapshot: UniFiPlanning.Snapshot
            do {
                snapshot = try await read(site_id)
            } catch let error as UniFiPlanning.ReadFailure {
                throw Failure.capture_failed(error)
            } catch {
                // Never serialize arbitrary provider errors to the model.
                throw Failure.capture_failed(
                    .init(stage: .validation, kind: .unexpected)
                )
            }
            guard snapshot.site_id == site_id else {
                throw Failure.capture_failed(
                    .init(stage: .validation, kind: .inconsistent_data)
                )
            }
            let id = UUID()
            snapshots[id] = snapshot
            return .init(snapshot_id: id, snapshot: snapshot)
        }

        private func stored(_ id: UUID) throws -> UniFiPlanning.Snapshot {
            guard let value = snapshots[id] else { throw Failure.unknown_snapshot }
            return value
        }

        public func networks(snapshot_id: UUID) throws -> NetworkList {
            let snapshot = try stored(snapshot_id)
            return .init(networks: Inventory(snapshot_id: snapshot_id, snapshot: snapshot)
                .networks.sorted { $0.vlan_id < $1.vlan_id })
        }

        public func zones(snapshot_id: UUID) throws -> ZoneList {
            let snapshot = try stored(snapshot_id)
            return .init(zones: Inventory(snapshot_id: snapshot_id, snapshot: snapshot)
                .zones.sorted { $0.label < $1.label })
        }

        public func network(snapshot_id: UUID, network_id: UUID) throws -> NetworkDetail {
            let snapshot = try stored(snapshot_id)
            let inventory = Inventory(snapshot_id: snapshot_id, snapshot: snapshot)
            guard let network = inventory.networks.first(where: { $0.id == network_id }) else {
                throw Failure.unknown_network
            }
            let zones = inventory.zones.filter { $0.network_ids.contains(network_id) || $0.id == network.zone_id }
            return .init(
                network: network,
                zones: zones,
                policy_count_for_zones: inventory.policies.filter { policy in
                    zones.contains(where: { $0.id == policy.source_zone_id || $0.id == policy.destination_zone_id })
                }.count
            )
        }

        public func policies(_ query: PolicyQuery) throws -> PolicyPage {
            let snapshot = try stored(query.snapshot_id)
            let inventory = Inventory(snapshot_id: query.snapshot_id, snapshot: snapshot)
            guard (query.offset ?? 0) >= 0, (query.limit ?? 25) > 0 else {
                throw Failure.invalid_query
            }
            let selection = inventory.policies.filter { policy in
                (query.zone_id == nil || policy.source_zone_id == query.zone_id || policy.destination_zone_id == query.zone_id) &&
                (query.enabled == nil || policy.enabled == query.enabled) &&
                (query.action == nil || policy.action == query.action?.uppercased())
            }.sorted { a, b in
                a.index == b.index ? a.id.uuidString < b.id.uuidString : a.index < b.index
            }
            let offset = min(query.offset ?? 0, selection.count)
            let limit = min(query.limit ?? 25, 50)
            return .init(total_count: selection.count, offset: offset,
                         policies: Array(selection.dropFirst(offset).prefix(limit)))
        }

        public func policy(snapshot_id: UUID, policy_id: UUID) throws -> PolicyDetail {
            let snapshot = try stored(snapshot_id)
            let inventory = Inventory(snapshot_id: snapshot_id, snapshot: snapshot)
            guard let raw = snapshot.policies.first(where: { $0.id == policy_id }),
                  let policy = inventory.policies.first(where: { $0.id == policy_id }) else {
                throw Failure.unknown_policy
            }
            func selection(_ value: UniFiPlanning.TrafficSelection?) -> TrafficSelection? {
                guard let value else { return nil }
                let ports: PortSelection? = value.ports.map { selection in
                    .init(
                        type: UniFi.safe_enum(selection.type) ?? "UNKNOWN",
                        match_opposite: selection.match_opposite,
                        items: selection.items?.map { item in
                            .init(type: UniFi.safe_enum(item.type) ?? "UNKNOWN",
                                  value: item.value, start: item.start, stop: item.stop)
                        },
                        traffic_matching_list_id: selection.traffic_matching_list_id
                    )
                }
                return .init(
                    type: UniFi.safe_enum(value.type) ?? "UNKNOWN",
                    network_ids: value.network_ids,
                    network_match_opposite: value.network_match_opposite,
                    ports: ports,
                    other_filter_details_unavailable: true
                )
            }
            let protocol_selection: ProtocolSelection? = raw.protocol_selection.map {
                .init(type: UniFi.safe_enum($0.type) ?? "UNKNOWN",
                      match_opposite: $0.match_opposite,
                      name: UniFi.safe_enum($0.name),
                      preset: UniFi.safe_enum($0.preset), number: $0.number)
            }
            return .init(
                policy: policy, source: selection(raw.source_selection),
                destination: selection(raw.destination_selection),
                protocol_selection: protocol_selection,
                ip_version: UniFi.safe_enum(raw.ip_version) ?? "UNKNOWN",
                return_traffic: raw.return_traffic,
                connection_states: raw.connection_states?.compactMap(UniFi.safe_enum),
                ipsec_filter: UniFi.safe_enum(raw.ipsec_filter),
                schedule: UniFi.safe_enum(raw.schedule),
                raw_addresses_and_descriptions_omitted: true
            )
        }

        public func inspect_path(_ query: TrafficPathQuery) throws -> TrafficPathInspection {
            let snapshot = try stored(query.snapshot_id)
            let inventory = Inventory(snapshot_id: query.snapshot_id, snapshot: snapshot)
            guard let source = inventory.networks.first(where: { $0.id == query.source_network_id }),
                  let destination = inventory.networks.first(where: { $0.id == query.destination_network_id }) else {
                throw Failure.unknown_network
            }
            func zone(for network: Network) -> Zone? {
                inventory.zones.first(where: { $0.network_ids.contains(network.id) || $0.id == network.zone_id })
            }
            guard let from = zone(for: source), let to = zone(for: destination) else {
                throw Failure.unresolved_path
            }
            let candidates = inventory.policies.filter { $0.source_zone_id == from.id && $0.destination_zone_id == to.id }
                .sorted { a, b in a.index == b.index ? a.id.uuidString < b.id.uuidString : a.index < b.index }
            return .init(
                source_network: source, destination_network: destination,
                source_zone: from, destination_zone: to,
                candidate_policies: Array(candidates.prefix(50)), candidate_count: candidates.count,
                port_evaluated: false, protocol_evaluated: false,
                effective_behavior_verified: false,
                limitation: "Only direct zone-pair candidate rules, first 50. No filter, port, protocol, precedence, default or packet evaluation; no allow/deny conclusion."
            )
        }

        public func prepare(_ request: PlanRequest) throws -> PlanPreview {
            guard let snapshot = snapshots[request.snapshot_id] else {
                throw Failure.unknown_snapshot
            }
            let changes: [UniFiPlanning.Change] =
                request.zone_memberships.map {
                    .set_zone_networks(
                        zone_id: $0.zone_id,
                        network_ids: $0.network_ids
                    )
                } + request.policy_telemetry.map {
                    .patch_policy_telemetry(
                        policy_id: $0.policy_id,
                        logging_enabled: $0.logging_enabled,
                        report_flow_enabled: $0.report_flow_enabled
                    )
                }
            let plan: UniFiPlanning.Plan
            do {
                plan = try .prepare(from: snapshot, changes: changes)
            } catch {
                throw Failure.invalid_plan
            }
            let id = UUID()
            plans[id] = (request.snapshot_id, plan)
            return .init(plan_id: id, snapshot_id: request.snapshot_id, plan: plan)
        }

        public func inspect(plan_id: UUID) throws -> PlanPreview {
            guard let stored = plans[plan_id] else {
                throw Failure.unknown_plan
            }
            return .init(
                plan_id: plan_id,
                snapshot_id: stored.snapshot_id,
                plan: stored.plan
            )
        }
    }
}
