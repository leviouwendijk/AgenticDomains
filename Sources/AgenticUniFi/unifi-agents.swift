import Agentic
import Foundation
import Macros
import Schema
// extra
import AgenticStandard
import AgenticMath
import AgenticAssertions

public extension UniFi.Agents {
    @Agent
    enum Inspector {
        @JSONSchema
        public struct Input: HashableSource {
            public let site_id: UUID?
            public let objective: String

            public init(site_id: UUID? = nil, objective: String) {
                self.site_id = site_id
                self.objective = objective
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let findings: [String]
            public let uncertainties: [String]
            public let recommendations: [String]

            public init(
                findings: [String],
                uncertainties: [String] = [],
                recommendations: [String] = []
            ) {
                self.findings = findings
                self.uncertainties = uncertainties
                self.recommendations = recommendations
            }
        }

        public static let purpose =
            "Inspect an explicitly selected UniFi site with read-only tools and report redacted findings."
        public static let instructions =
            UniFi.Instructions.ReadOnly.content + "\n" + UniFi.Instructions.Hardening.content

        public static let capabilities = AgentCapabilities(
            available: .init(
                tools: .init(members: [
                    UniFi.Tools.ListSites.definition.identifier,
                    UniFi.Tools.CaptureSnapshot.definition.identifier,
                    UniFi.Tools.ListNetworks.definition.identifier,
                    UniFi.Tools.ListZones.definition.identifier,
                    UniFi.Tools.ListPolicies.definition.identifier,
                    UniFi.Tools.InspectNetwork.definition.identifier,
                    UniFi.Tools.InspectPolicy.definition.identifier,
                    UniFi.Tools.InspectTrafficPath.definition.identifier,
                    UniFi.Tools.InspectPlan.definition.identifier,
                ])
            ),
            visible: .init(
                tools: .init(members: [
                    UniFi.Tools.ListSites.definition.identifier,
                    UniFi.Tools.CaptureSnapshot.definition.identifier,
                    UniFi.Tools.ListNetworks.definition.identifier,
                    UniFi.Tools.ListZones.definition.identifier,
                    UniFi.Tools.ListPolicies.definition.identifier,
                    UniFi.Tools.InspectNetwork.definition.identifier,
                    UniFi.Tools.InspectPolicy.definition.identifier,
                    UniFi.Tools.InspectTrafficPath.definition.identifier,
                    UniFi.Tools.InspectPlan.definition.identifier,
                ])
            )
        )
    }

    @Agent
    enum Manager {
        @JSONSchema
        public struct Input: HashableSource {
            public let site_id: UUID?
            public let objective: String
            public let constraints: [String]

            public init(
                site_id: UUID? = nil,
                objective: String,
                constraints: [String] = []
            ) {
                self.site_id = site_id
                self.objective = objective
                self.constraints = constraints
            }
        }

        @JSONSchema
        public struct Output: HashableResult {
            public let proposed_plan_ids: [UUID]
            public let reasoning: [String]
            public let verification_gaps: [String]

            public init(
                proposed_plan_ids: [UUID] = [],
                reasoning: [String] = [],
                verification_gaps: [String] = []
            ) {
                self.proposed_plan_ids = proposed_plan_ids
                self.reasoning = reasoning
                self.verification_gaps = verification_gaps
            }
        }

        public static let purpose =
            "Inspect and propose bounded UniFi network-management changes without executing controller writes."
        public static let instructions =
            UniFi.Instructions.ReadOnly.content + "\n" +
            UniFi.Instructions.Mutation.content + "\n" +
            UniFi.Instructions.Hardening.content

        public static let capabilities = AgentCapabilities(
            available: .init(
                domains: [
                    Standard.self,
                    // Harness.self,
                    Math.self,
                    Assertions.self,
                    UniFi.self,
                ],
                // tools: .init(
                //     members: [
                //         UniFi.Tools.ListSites.definition.identifier,
                //         UniFi.Tools.CaptureSnapshot.definition.identifier,
                //         UniFi.Tools.ListNetworks.definition.identifier,
                //         UniFi.Tools.ListZones.definition.identifier,
                //         UniFi.Tools.ListPolicies.definition.identifier,
                //         UniFi.Tools.InspectNetwork.definition.identifier,
                //         UniFi.Tools.InspectPolicy.definition.identifier,
                //         UniFi.Tools.InspectTrafficPath.definition.identifier,
                //         UniFi.Tools.PlanChanges.definition.identifier,
                //         UniFi.Tools.InspectPlan.definition.identifier,
                //     ]
                // )
            ),
            visible: .init(
                tools: .init(
                    members: [
                        Standard.Tools.ClarifyWithUser.self,
                        Standard.Tools.InspectCapability.self,

                        Standard.Tools.CreateGraph.self,
                        Standard.Tools.CreateReport.self,
                        Standard.Tools.CreateCallTree.self,

                        UniFi.Tools.ListSites.self,
                        UniFi.Tools.CaptureSnapshot.self,
                        UniFi.Tools.ListNetworks.self,
                        UniFi.Tools.ListZones.self,
                        UniFi.Tools.ListPolicies.self,
                        UniFi.Tools.InspectNetwork.self,
                        UniFi.Tools.InspectPolicy.self,
                        UniFi.Tools.InspectTrafficPath.self,
                        UniFi.Tools.PlanChanges.self,
                        UniFi.Tools.InspectPlan.self,
                    ]
                )
            )
        )
    }
}
