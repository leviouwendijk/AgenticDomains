import AgenticAppleServices
import Agentic
import TestFlows

extension AgenticDomainsFlowTesting {
    static func runAgenticAppleServicesToolSurface() async throws
        -> [TestFlowDiagnostic]
    {
        var registry = ToolRegistry()

        try registry.register(
            AgenticAppleServicesToolSet()
        )

        try Expect.equal(
            registry.count,
            21,
            "AgenticAppleServices registered tool count across Calendar, Reminders, Weather, and Location"
        )

        let names =
            registry.definitions
                .map(\.name)
                .sorted()

        try Expect.equal(
            names,
            [
                "calendar_authorization_status",
                "calendar_events",
                "calendar_request_full_access",
                "location_authorization_status",
                "location_current",
                "location_request_when_in_use",
                "music_catalog_authorization_status",
                "music_catalog_authorize",
                "music_catalog_play",
                "music_catalog_search",
                "music_control",
                "music_now_playing",
                "music_play",
                "music_search",
                "music_set_volume",
                "reminders",
                "reminders_authorization_status",
                "reminders_create",
                "reminders_request_full_access",
                "weather_current",
                "weather_forecast",
            ],
            "AgenticAppleServices registers the initial Calendar, Reminders, Weather, and Location surfaces"
        )

        let missingSemanticSchemas =
            registry.capabilities
                .filter {
                    $0.semanticInputSchema == nil
                }
                .map(\.definition.name)
                .sorted()

        try Expect.equal(
            missingSemanticSchemas,
            [String](),
            "AgenticAppleServices registered tools all project semantic input schemas"
        )

        return [
            .field(
                "registered",
                "\(registry.count)"
            ),
        ]
    }
}
