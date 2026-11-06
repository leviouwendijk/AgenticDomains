import Agentic
import Foundation
import Macros
import Schema

public extension UniFi.Agents {
    @Agent
    enum Inspector {
        @JSONSchema
        public struct Input: HashableSource {
            public let site_id: UUID
            public let objective: String

            public init(site_id: UUID, objective: String) {
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
                    UniFi.Tools.CaptureSnapshot.definition.identifier,
                    UniFi.Tools.InspectPlan.definition.identifier,
                ])
            )
        )
    }

    @Agent
    enum Manager {
        @JSONSchema
        public struct Input: HashableSource {
            public let site_id: UUID
            public let objective: String
            public let constraints: [String]

            public init(
                site_id: UUID,
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
                tools: .init(members: [
                    UniFi.Tools.CaptureSnapshot.definition.identifier,
                    UniFi.Tools.PlanChanges.definition.identifier,
                    UniFi.Tools.InspectPlan.definition.identifier,
                ])
            )
        )
    }
}
