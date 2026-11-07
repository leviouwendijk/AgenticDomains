import Agentic
import Foundation
import Macros
import Schema

public extension UniFi.Tools {
    @Tool("unifi_list_sites")
    struct ListSites {
        @JSONSchema
        public struct Input: Sendable, Codable, Hashable {
            public init() {}
        }

        public typealias Output = UniFi.SiteDirectory
        public static let purpose =
            "Discover all authorized UniFi sites and their UUIDs. Return only numbered identifiers, not site names or controller details."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try context.require(UniFi.Runtime.self)
            return try await runtime.sites()
        }
    }

    @Tool("unifi_capture_snapshot")
    struct CaptureSnapshot {
        @JSONSchema
        public struct Input: Sendable, Codable, Hashable {
            public let site_id: UUID

            public init(site_id: UUID) {
                self.site_id = site_id
            }
        }

        public typealias Output = UniFi.Inventory
        public static let purpose =
            "Capture an authorized UniFi site's network, zone and firewall-policy state. Return only IP-redacted topology metadata and an opaque snapshot ID."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try context.require(UniFi.Runtime.self)
            return try await runtime.capture(site_id: input.site_id)
        }
    }

    @Tool("unifi_list_networks")
    struct ListNetworks {
        @JSONSchema
        public struct Input: Sendable, Codable, Hashable {
            public let snapshot_id: UUID
        }
        public typealias Output = UniFi.NetworkList
        public static let purpose = "List VLANs and privacy-screened display labels from a captured snapshot."
        public static let risk: ActionRisk = .observe
        public init() {}
        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            try await context.require(UniFi.Runtime.self).networks(snapshot_id: input.snapshot_id)
        }
    }

    @Tool("unifi_list_zones")
    struct ListZones {
        @JSONSchema
        public struct Input: Sendable, Codable, Hashable {
            public let snapshot_id: UUID
        }
        public typealias Output = UniFi.ZoneList
        public static let purpose = "List firewall zones, privacy-screened display labels, membership IDs and missing references from a captured snapshot."
        public static let risk: ActionRisk = .observe
        public init() {}
        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            try await context.require(UniFi.Runtime.self).zones(snapshot_id: input.snapshot_id)
        }
    }

    @Tool("unifi_list_policies")
    struct ListPolicies {
        public typealias Input = UniFi.PolicyQuery
        public typealias Output = UniFi.PolicyPage
        public static let purpose = "Page firewall policy summaries from a snapshot; optional zone, enabled and action filters, sorted by observed index."
        public static let risk: ActionRisk = .observe
        public init() {}
        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            try await context.require(UniFi.Runtime.self).policies(input)
        }
    }

    @Tool("unifi_inspect_network")
    struct InspectNetwork {
        @JSONSchema
        public struct Input: Sendable, Codable, Hashable {
            public let snapshot_id: UUID
            public let network_id: UUID
        }
        public typealias Output = UniFi.NetworkDetail
        public static let purpose = "Inspect one captured network's VLAN, safe label and reported firewall-zone membership."
        public static let risk: ActionRisk = .observe
        public init() {}
        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            try await context.require(UniFi.Runtime.self).network(snapshot_id: input.snapshot_id, network_id: input.network_id)
        }
    }

    @Tool("unifi_inspect_policy")
    struct InspectPolicy {
        @JSONSchema
        public struct Input: Sendable, Codable, Hashable {
            public let snapshot_id: UUID
            public let policy_id: UUID
        }
        public typealias Output = UniFi.PolicyDetail
        public static let purpose = "Inspect one captured rule's zone labels, protocol, optional TCP/UDP port and network selectors, and stated parsing gaps; never show address filters or descriptions."
        public static let risk: ActionRisk = .observe
        public init() {}
        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            try await context.require(UniFi.Runtime.self).policy(snapshot_id: input.snapshot_id, policy_id: input.policy_id)
        }
    }

    @Tool("unifi_inspect_traffic_path")
    struct InspectTrafficPath {
        public typealias Input = UniFi.TrafficPathQuery
        public typealias Output = UniFi.TrafficPathInspection
        public static let purpose = "Find candidate zone-pair firewall rules for two captured networks; NOT a packet simulator or proof of allow/deny, and does NOT evaluate the requested port or protocol."
        public static let risk: ActionRisk = .observe
        public init() {}
        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            try await context.require(UniFi.Runtime.self).inspect_path(input)
        }
    }

    /// Deliberately privileged: auto_bounded_mutate otherwise skips human review.
    /// The trusted host must also inject TelemetryWriter with its own approver.
    @Tool("unifi_apply_policy_telemetry")
    struct ApplyPolicyTelemetry {
        public typealias Input = UniFi.ApplyTelemetryRequest
        public typealias Output = UniFi.ApplyTelemetryResult
        public static let purpose =
            "Apply exactly one approved, previously prepared USER_DEFINED policy telemetry change; perform fresh-state checks and independent verification. Requires trusted host writer."
        public static let risk: ActionRisk = .privileged
        public init() {}

        public func preflight(_ input: Input, in context: ToolContext) async throws -> ToolPreflight {
            let summary = try await context.require(UniFi.Runtime.self).telemetry_review(plan_id: input.plan_id)
            return ToolPreflight(
                tool: Self.definition.identifier,
                risk: Self.definition.risk,
                summary: summary,
                estimates: .init(write: .init(count: 1)),
                sideEffects: ["PATCH one firewall policy's telemetry fields"],
                policyChecks: [
                    "single_prepared_telemetry_change",
                    "host_review_required",
                    "trusted_writer_required",
                    "fresh_policy_equality_before_patch",
                    "host_injected_sdk_approver",
                    "independent_get_after_patch",
                    "single_use_plan"
                ],
                warnings: [
                    "Policy telemetry affects logging/flow reporting, not forwarding rules.",
                    "Controller writes are not atomic; unknown outcomes must not be retried."
                ]
            )
        }

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            try await context.require(UniFi.Runtime.self).apply_telemetry(input)
        }
    }

    @Tool("unifi_plan_changes")
    struct PlanChanges {
        public typealias Input = UniFi.PlanRequest
        public typealias Output = UniFi.PlanPreview

        public static let purpose =
            "Prepare an offline, non-executing UniFi zone-membership or firewall-telemetry change plan using a captured snapshot. Return a redacted graph preview; never write to the controller."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try context.require(UniFi.Runtime.self)
            return try await runtime.prepare(input)
        }
    }

    @Tool("unifi_inspect_plan")
    struct InspectPlan {
        @JSONSchema
        public struct Input: Sendable, Codable, Hashable {
            public let plan_id: UUID

            public init(plan_id: UUID) {
                self.plan_id = plan_id
            }
        }

        public typealias Output = UniFi.PlanPreview
        public static let purpose =
            "Inspect an existing offline UniFi plan by opaque ID. Show its redacted graph difference without applying it."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(_ input: Input, in context: ToolContext) async throws -> Output {
            let runtime = try context.require(UniFi.Runtime.self)
            return try await runtime.inspect(plan_id: input.plan_id)
        }
    }
}

