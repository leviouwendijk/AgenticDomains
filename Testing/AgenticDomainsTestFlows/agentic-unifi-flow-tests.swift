import Agentic
import AgenticUniFi
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
        let runtime = UniFi.Runtime(read: { _ in snapshot })
        let installation = UniFiInstallationProbe()
        UniFi.installation.install(into: installation)
        try Expect.equal(installation.registration_errors, 0, "macro installers register without errors")
        let registry = installation.registry
        let context = ToolContext(
            services: try ToolServices().inserting(runtime)
        )
        try Expect.equal(registry.count, 3, "UniFi macro installs all three tools")
        try Expect.equal(
            registry.definitions.map(\.name).sorted(),
            ["unifi_capture_snapshot", "unifi_inspect_plan", "unifi_plan_changes"],
            "UniFi tool naming"
        )
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
        let emitted = String(decoding: try JSONEncoder().encode(inventory), as: UTF8.self)
            + String(decoding: try JSONEncoder().encode(plan), as: UTF8.self)
        try Expect.equal(emitted.contains("10.42.1.0"), false, "no private subnet in tool results")
        try Expect.equal(emitted.contains("192.168.5.1"), false, "no private address in tool results")
        return [.field("tools", "3"), .field("plans", "1")]
    }
}
