import Agentic

public extension UniFi.Instructions {
    @Instruction
    enum ReadOnly: Instruction {
        public static let content = """
        Use only registered UniFi read tools for inspection. When no site ID is
        supplied, discover accessible sites with unifi_list_sites. If exactly one
        site exists, use its UUID. If multiple sites exist, request explicit
        selection by ordinal or UUID before accessing site-specific data.
        Never guess a site; a zero-site result is not a valid default.
        Capture a fresh snapshot for each investigation. Report observed network, zone,
        policy, VLAN and rule-order metadata separately from any interpretation.
        Use only privacy-screened display labels emitted by UniFi tools, not raw
        controller names. Never echo policy descriptions, address ranges, gateway
        addresses, MAC addresses, credentials, controller URLs or IP addresses.
        Label screening only checks syntax and cannot rule out secrets embedded
        in ordinary words; do not treat labels as public or export them externally.
        After capturing a snapshot, use snapshot-scoped targeted network, zone,
        policy and path inspection tools; never infer effective traffic behavior
        from candidate policies, port filters, or ordering indexes alone.
        Treat missing filters, effective precedence, packet tests and unsupported API
        fields as unknown, not as evidence of safety or connectivity.
        """
    }

    @Instruction
    enum Mutation: Instruction {
        public static let content = """
        A proposed plan is not permission to execute. The current UniFi tool set
        offers planning only; it contains no controller-writing tool.
        For future writes: require explicit human approval over a complete, redacted
        preflight; obtain a fresh complete state immediately before execution; reject
        stale or partial state; use narrow, authorized operations; verify by an
        independent read; and stop on ambiguity or any risk to management access.
        Never suggest that offline graph verification proves packet-level behavior.
        """
    }

    @Instruction
    enum Hardening: Instruction {
        public static let content = """
        Review isolation intent, rule ordering, remote management, IPv4/IPv6 parity,
        VPN and management reachability, unused allowances, logging and observability.
        Make recommendations as proposals with their evidence, uncertainty,
        operational impact and rollback considerations; do not silently apply them.
        Preserve controller access and known-good traffic paths. Do not infer firewall
        effectiveness from zone and policy summaries alone; request the missing
        filtering, endpoint, ordering and effective-rule evidence first.
        """
    }
}
