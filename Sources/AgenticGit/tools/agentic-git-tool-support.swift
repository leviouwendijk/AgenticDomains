import Agentic
import AgenticExecution
import AgenticWorkspace
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
        try await requireRepositoryRoot(
            workspace.rootURL,
            toolName: toolName
        )
    }

    static func requireRepositoryRoot(
        _ workingDirectory: URL,
        toolName: String
    ) async throws {
        let workingDirectory =
            workingDirectory
                .standardizedFileURL
        let state =
            try await GitManagerRepositoryInspector
                .state(
                    at: workingDirectory,
                    fetch: false
                )

        guard let repositoryRoot =
            state.root?
                .standardizedFileURL
        else {
            throw GitManagerError.notGitRepository(
                workingDirectory.path
            )
        }

        guard repositoryRoot.path
            == workingDirectory.path
        else {
            throw AgenticGitToolError
                .repositoryRootWorkspaceRequired(
                    toolName: toolName,
                    workspaceRoot:
                        workingDirectory.path,
                    repositoryRoot:
                        repositoryRoot.path
                )
        }
    }
}
