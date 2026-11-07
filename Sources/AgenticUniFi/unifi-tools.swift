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

