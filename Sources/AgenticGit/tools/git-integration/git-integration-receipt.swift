import Foundation
import Interfaces

enum AgenticGitIntegrationReceipt {
    static func encode<T>(
        _ value: T
    ) throws -> String
    where T: Encodable {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let data = try encoder.encode(value)

        guard let string = String(
            data: data,
            encoding: .utf8
        ) else {
            throw GitManagerError.unsafeSync(
                "Unable to encode Agentic Git integration receipt as UTF-8."
            )
        }

        return string
    }

    static func decode<T>(
        _ type: T.Type,
        from receipt: String
    ) throws -> T
    where T: Decodable {
        guard let data = receipt.data(
            using: .utf8
        ) else {
            throw GitManagerError.unsafeSync(
                "Agentic Git integration receipt is not UTF-8."
            )
        }

        return try JSONDecoder().decode(
            type,
            from: data
        )
    }
}
