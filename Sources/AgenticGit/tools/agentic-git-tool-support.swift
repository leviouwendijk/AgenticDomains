import Agentic
import Foundation
import Interfaces

enum AgenticGitToolSupport {
    static func requireWorkspace(
        _ workspace: AgentWorkspace?,
        toolName: String
    ) throws -> AgentWorkspace {
        guard let workspace else {
            throw AgenticGitToolError.workspaceRequired(
                toolName
            )
        }

        return workspace
    }

    static func requireRepositoryRoot(
        _ workspace: AgentWorkspace,
        toolName: String
    ) async throws {
        let state =
            try await GitManagerRepositoryInspector
                .state(
                    at: workspace.rootURL,
                    fetch: false
                )

        guard let repositoryRoot =
            state.root?
                .standardizedFileURL
        else {
            throw GitManagerError.notGitRepository(
                workspace.rootURL.path
            )
        }

        let workspaceRoot =
            workspace.rootURL
                .standardizedFileURL

        guard repositoryRoot.path
            == workspaceRoot.path
        else {
            throw AgenticGitToolError
                .repositoryRootWorkspaceRequired(
                    toolName: toolName,
                    workspaceRoot:
                        workspaceRoot.path,
                    repositoryRoot:
                        repositoryRoot.path
                )
        }
    }
}
