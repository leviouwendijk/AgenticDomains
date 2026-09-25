import Agentic
import Foundation
import Interfaces
import Workspace

enum AgenticGitToolSupport {
    static func requireWorkspace(
        _ workspace: WorkspaceContext?,
        toolName: String
    ) throws -> WorkspaceContext {
        guard let workspace else {
            throw AgenticGitToolError.workspaceRequired(
                toolName
            )
        }

        return workspace
    }

    static func requireRepositoryRoot(
        _ workspace: WorkspaceContext,
        toolName: String
    ) async throws {
        try await requireRepositoryRoot(
            workspace.absoluteURL,
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