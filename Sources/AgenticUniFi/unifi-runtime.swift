import Difference
import Errors
import Foundation
import Macros
import Schema
import UniFiPlanning

public extension UniFi {
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
        public let vlan_id: Int
        public let enabled: Bool
        public let zone_id: UUID?
    }

    @JSONSchema
    struct Zone: Sendable, Codable, Hashable {
        public let id: UUID
        public let network_ids: [UUID]
        public let user_defined: Bool
    }

    @JSONSchema
    struct Policy: Sendable, Codable, Hashable {
        public let id: UUID
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
                    vlan_id: network.vlan_id,
                    enabled: network.enabled,
                    zone_id: network.zone_id
                )
            }
            zones = snapshot.zones.map { zone in
                .init(
                    id: zone.id,
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
            case unknown_plan
            case invalid_plan

            public var description: String {
                switch self {
                case .site_discovery_failed(let detail):
                    return "site_discovery_failed " + detail.description
                case .capture_failed(let detail):
                    return "capture_failed " + detail.description
                case .unknown_snapshot:
                    return "unknown_snapshot"
                case .unknown_plan:
                    return "unknown_plan"
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
