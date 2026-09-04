import Agentic
import AgenticExecution
import AgenticWorkspace
import Foundation
import Interfaces
import Primitives
import Schema
import SchemaMacros

/// Push committed Git history for the current Agentic workspace repository.
/// Omit both remote and branch to use the repository's configured/default upstream resolution.
/// Supply both remote and branch to approve an explicit push destination.
/// This tool never checks out or changes branches.
@JSONSchema
public struct GitPushToolInput:
    Sendable,
    Codable,
    Hashable
{
    /// Optional explicit Git remote name. Must be supplied together with branch.
    public let remote: String?

    /// Optional explicit local branch or HEAD to push. Must be supplied together with remote. This does not switch branches.
    public let branch: String?

    /// When an explicit remote and branch are supplied, whether to set that destination as upstream. Defaults to true.
    @Schema(required: false)
    public let setUpstream: Bool

    public init(
        remote: String? = nil,
        branch: String? = nil,
        setUpstream: Bool = true
    ) {
        self.remote = remote
        self.branch = branch
        self.setUpstream = setUpstream
    }
}

private extension GitPushToolInput {
    enum CodingKeys:
        String,
        CodingKey
    {
        case remote
        case branch
        case setUpstream
    }
}

public extension GitPushToolInput {
    init(
        from decoder: Decoder
    ) throws {
        let container =
            try decoder.container(
                keyedBy: CodingKeys.self
            )

        self.init(
            remote:
                try container.decodeIfPresent(
                    String.self,
                    forKey: .remote
                ),
            branch:
                try container.decodeIfPresent(
                    String.self,
                    forKey: .branch
                ),
            setUpstream:
                try container.decodeIfPresent(
                    Bool.self,
                    forKey: .setUpstream
                ) ?? true
        )
    }
}

public extension GitPushToolInput {


    func validatedTarget()
        throws -> (remote: String, branch: String)?
    {
        let remote = normalized(
            self.remote
        )

        let branch = normalized(
            self.branch
        )

        switch (remote, branch) {
        case (.none, .none):
            return nil

        case (.some, .none), (.none, .some):
            throw GitManagerError.unsafeSync(
                "git_push requires both remote and branch when selecting an explicit destination. Omit both to use the configured upstream."
            )

        case let (.some(remote), .some(branch)):
            guard validRemote(remote) else {
                throw GitManagerError.unsafeSync(
                    "Invalid explicit Git remote for git_push: \(remote)"
                )
            }

            guard validBranch(branch) else {
                throw GitManagerError.unsafeSync(
                    "Invalid explicit Git branch for git_push: \(branch)"
                )
            }

            return (
                remote: remote,
                branch: branch
            )
        }
    }
}

private extension GitPushToolInput {
    func normalized(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty
            ? nil
            : trimmed
    }

    func validRemote(
        _ value: String
    ) -> Bool {
        guard !value.hasPrefix("-") else {
            return false
        }

        return value.allSatisfy {
            $0.isLetter
                || $0.isNumber
                || $0 == "."
                || $0 == "_"
                || $0 == "-"
        }
    }

    func validBranch(
        _ value: String
    ) -> Bool {
        guard !value.hasPrefix("-"),
              !value.contains(".."),
              !value.contains("@{"),
              !value.contains("//"),
              !value.hasSuffix("."),
              !value.hasSuffix("/")
        else {
            return false
        }

        return value.allSatisfy {
            $0.isLetter
                || $0.isNumber
                || $0 == "."
                || $0 == "_"
                || $0 == "-"
                || $0 == "/"
        }
    }
}

public struct GitPushToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let remote: String?
    public let branch: String?
    public let configuredTarget: String?
    public let currentBranch: String?
    public let setUpstream: Bool
    public let output: String

    public init(
        remote: String?,
        branch: String?,
        configuredTarget: String?,
        currentBranch: String?,
        setUpstream: Bool,
        output: String
    ) {
        self.remote = remote
        self.branch = branch
        self.configuredTarget = configuredTarget
        self.currentBranch = currentBranch
        self.setUpstream = setUpstream
        self.output = output
    }
}

public struct GitPushTool:
    AgentTool
{
    public typealias Input = GitPushToolInput
    public typealias Output = GitPushToolOutput
    public static let identifier:
        AgentToolIdentifier =
            "git_push"

    public static let description =
        """
        Push committed Git history to the configured upstream or to an explicitly approved remote and branch without changing branches.
        """

    public static let risk:
        ActionRisk =
            .privileged

    public var identifier: AgentToolIdentifier {
        Self.identifier
    }

    public var description: String {
        Self.description
    }

    public var risk: ActionRisk {
        Self.risk
    }

    public init() {}


}
