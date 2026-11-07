import Agentic
import AgenticUniFi
import Errors
import Foundation
import TestFlows
import UniFiPlanning

extension AgenticDomainsFlowTesting {
    static func runUniFiPlanningBoundary() async throws -> [TestFlowDiagnostic] {
        guard let site_id = UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
              let network_id = UUID(uuidString: "00000000-0000-0000-0000-000000000002"),
              let zone_id = UUID(uuidString: "00000000-0000-0000-0000-000000000003") else {
            throw UniFiPlanning.Failure.invalid_change
        }
        let fixture = #"{"site_id":"00000000-0000-0000-0000-000000000001","networks":[{"id":"00000000-0000-0000-0000-000000000002","name":"10.42.1.0/24","vlan_id":42,"enabled":true,"zone_id":null}],"zones":[{"id":"00000000-0000-0000-0000-000000000003","name":"192.168.5.1 private","network_ids":[],"origin":"USER_DEFINED"}],"policies":[]}"#
        let snapshot = try JSONDecoder().decode(
            UniFiPlanning.Snapshot.self,
            from: Data(fixture.utf8)
        )
        let runtime = UniFi.Runtime(
            read: { _ in snapshot },
            list_sites: { [site_id] }
        )
        let installation = UniFiInstallationProbe()
        UniFi.installation.install(into: installation)
        try Expect.equal(installation.registration_errors, 0, "macro installers register without errors")
        let registry = installation.registry
        let context = ToolContext(
            services: try ToolServices().inserting(runtime)
        )
        try Expect.equal(registry.count, 11, "UniFi macro installs ten inspection/planning tools and one privileged telemetry apply tool")
        try Expect.equal(UniFi.Tools.ApplyPolicyTelemetry.definition.risk, .privileged,
                         "telemetry writes are reviewed even under auto_bounded_mutate")
        try Expect.equal(
            registry.definitions.map(\.name).sorted(),
            ["unifi_apply_policy_telemetry", "unifi_capture_snapshot", "unifi_inspect_network", "unifi_inspect_plan", "unifi_inspect_policy", "unifi_inspect_traffic_path", "unifi_list_networks", "unifi_list_policies", "unifi_list_sites", "unifi_list_zones", "unifi_plan_changes"],
            "UniFi tool naming"
        )
        let discovery = try await registry.execute(
            ToolCall(
                id: "sites",
                tool: UniFi.Tools.ListSites.definition.identifier,
                input: .object([:])
            ),
            context: context
        )
        let directory = try discovery.result.output.decode(UniFi.SiteDirectory.self)
        try Expect.equal(directory.sites.map(\.site_id), [site_id], "site discovery yields the fixture site")
        try Expect.equal(directory.sites.map(\.ordinal), [1], "site selection numbering")
        let capture = try await registry.execute(
            ToolCall(
                id: "capture",
                tool: UniFi.Tools.CaptureSnapshot.definition.identifier,
                input: .object([
                    "site_id": .string(site_id.uuidString),
                ])
            ),
            context: context
        )
        let inventory = try capture.result.output.decode(UniFi.Inventory.self)
        try Expect.equal(inventory.networks.count, 1, "one network")
        try Expect.equal(inventory.networks[0].label, "VLAN 42", "IP-shaped name suppressed")
        try Expect.equal(inventory.zones[0].label.contains("192.168"), false, "zone IP suppressed")
        let networkList = try await registry.execute(
            ToolCall(id: "networks", tool: UniFi.Tools.ListNetworks.definition.identifier,
                     input: .object(["snapshot_id": .string(inventory.snapshot_id.uuidString)])),
            context: context
        )
        let listed = try networkList.result.output.decode(UniFi.NetworkList.self)
        try Expect.equal(listed.networks.count, 1, "network listing from snapshot")
        let zones = try await registry.execute(
            ToolCall(id: "zones", tool: UniFi.Tools.ListZones.definition.identifier,
                     input: .object(["snapshot_id": .string(inventory.snapshot_id.uuidString)])),
            context: context
        )
        try Expect.equal(try zones.result.output.decode(UniFi.ZoneList.self).zones.count, 1, "zone listing")
        let detail = try await registry.execute(
            ToolCall(id: "network", tool: UniFi.Tools.InspectNetwork.definition.identifier,
                     input: .object([
                         "snapshot_id": .string(inventory.snapshot_id.uuidString),
                         "network_id": .string(network_id.uuidString),
                     ])), context: context
        )
        try Expect.equal(try detail.result.output.decode(UniFi.NetworkDetail.self).network.id, network_id,
                         "network inspection resolves by UUID")
        let page = try await registry.execute(
            ToolCall(id: "policies", tool: UniFi.Tools.ListPolicies.definition.identifier,
                     input: .object(["snapshot_id": .string(inventory.snapshot_id.uuidString)])),
            context: context
        )
        try Expect.equal(try page.result.output.decode(UniFi.PolicyPage.self).total_count, 0, "empty paginated policy fixture")
        let planned = try await registry.execute(
            ToolCall(
                id: "plan",
                tool: UniFi.Tools.PlanChanges.definition.identifier,
                input: .object([
                    "snapshot_id": .string(inventory.snapshot_id.uuidString),
                    "zone_memberships": .array([
                        .object([
                            "zone_id": .string(zone_id.uuidString),
                            "network_ids": .array([.string(network_id.uuidString)]),
                        ]),
                    ]),
                    "policy_telemetry": .array([]),
                ])
            ),
            context: context
        )
        let plan = try planned.result.output.decode(UniFi.PlanPreview.self)
        let inspection = try await registry.execute(
            ToolCall(
                id: "inspect",
                tool: UniFi.Tools.InspectPlan.definition.identifier,
                input: .object([
                    "plan_id": .string(plan.plan_id.uuidString),
                ])
            ),
            context: context.using(workspace: nil)
        )
        let inspected = try inspection.result.output.decode(UniFi.PlanPreview.self)
        try Expect.equal(plan, inspected, "plan token resolves the same redacted preview")
        let emitted = String(decoding: try JSONEncoder().encode(directory), as: UTF8.self)
            + String(decoding: try JSONEncoder().encode(inventory), as: UTF8.self)
            + String(decoding: try JSONEncoder().encode(plan), as: UTF8.self)
        try Expect.equal(emitted.contains("10.42.1.0"), false, "no private subnet in tool results")
        try Expect.equal(emitted.contains("192.168.5.1"), false, "no private address in tool results")
        let diagnostics = UniFiPlanning.ReadFailure(
            stage: .policies, kind: .decoding,
            coding_path: ["data", "index_0", "192.168.5.1"],
            field: "ipVersion"
        )
        let failing = UniFi.Runtime(read: { _ in throw diagnostics })
        do {
            _ = try await failing.capture(site_id: site_id)
            throw UniFiPlanning.Failure.invalid_change
        } catch UniFi.Runtime.Failure.capture_failed(let detail) {
            let report = detail.report.redacted(policy: .publicsafe)
            let text = String(describing: detail)
                + String(describing: report)
            try Expect.equal(detail.stage, .policies, "failure preserves request stage")
            try Expect.equal(detail.kind, .decoding, "failure preserves sanitized category")
            try Expect.equal(detail.field, "ipVersion", "failure preserves static schema key")
            try Expect.equal(text.contains("192.168.5.1"), false, "failure report hides arbitrary coding keys")
        }
        return [.field("tools", "11"), .field("sites", "1"), .field("plans", "1")]
    }
}
