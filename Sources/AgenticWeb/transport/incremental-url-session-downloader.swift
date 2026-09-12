import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class IncrementalURLSessionDownloader: NSObject, @unchecked Sendable {
    public struct Configuration: Sendable, Hashable {
        public let userAgent: String
        public let timeoutSeconds: TimeInterval

        public init(
            userAgent: String = "AgenticWeb/1.0",
            timeoutSeconds: TimeInterval = 15
        ) {
            self.userAgent = userAgent
            self.timeoutSeconds = timeoutSeconds
        }
    }

    private final class DownloadState {
        let maxBytes: Int
        let allowedContentTypes: Set<String>?
        let continuation: CheckedContinuation<IncrementalDownloadResponse, Error>

        var response: HTTPURLResponse?
        var body = Data()
        var redirectCount = 0
        var completed = false

        init(
            maxBytes: Int,
            allowedContentTypes: Set<String>?,
            continuation: CheckedContinuation<IncrementalDownloadResponse, Error>
        ) {
            self.maxBytes = maxBytes
            self.allowedContentTypes = allowedContentTypes
            self.continuation = continuation
        }
    }

    public let policy: WebAccessPolicy
    public let configuration: Configuration

    private var session: URLSession!
    private let stateQueue = DispatchQueue(
        label: "agenticweb.incremental-downloader.state"
    )
    private var states: [Int: DownloadState] = [:]

    public init(
        policy: WebAccessPolicy,
        configuration: Configuration = .init()
    ) {
        self.policy = policy
        self.configuration = configuration
        super.init()

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.httpCookieAcceptPolicy = .never
        sessionConfiguration.httpShouldSetCookies = false
        sessionConfiguration.urlCache = nil
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfiguration.timeoutIntervalForRequest = configuration.timeoutSeconds
        sessionConfiguration.timeoutIntervalForResource = configuration.timeoutSeconds
        sessionConfiguration.httpAdditionalHeaders = [
            "User-Agent": configuration.userAgent
        ]

        self.session = URLSession(
            configuration: sessionConfiguration,
            delegate: self,
            delegateQueue: nil
        )
    }

    public func download(
        _ request: URLRequest,
        maxBytes: Int,
        allowedContentTypes: Set<String>? = nil
    ) async throws -> IncrementalDownloadResponse {
        guard let url = request.url else {
            throw WebToolError.invalidURL("<missing request url>")
        }

        _ = try policy.validate(
            urlString: url.absoluteString
        )

        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(
                with: request
            )

            let state = DownloadState(
                maxBytes: maxBytes,
                allowedContentTypes: allowedContentTypes,
                continuation: continuation
            )

            stateQueue.sync {
                states[task.taskIdentifier] = state
            }

            task.resume()
        }
    }
}

extension IncrementalURLSessionDownloader: URLSessionDataDelegate, URLSessionTaskDelegate {
    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        _ = session

        guard let httpResponse = response as? HTTPURLResponse else {
            fail(
                taskID: dataTask.taskIdentifier,
                error: WebToolError.nonHTTPResponse
            )
            completionHandler(.cancel)
            dataTask.cancel()
            return
        }

        if let finalURL = httpResponse.url {
            do {
                _ = try policy.validate(
                    urlString: finalURL.absoluteString
                )
            } catch {
                fail(
                    taskID: dataTask.taskIdentifier,
                    error: error
                )
                completionHandler(.cancel)
                dataTask.cancel()
                return
            }
        }

        let validationError: Error? = stateQueue.sync {
            guard let state = states[dataTask.taskIdentifier] else {
                return WebToolError.transportFailure(
                    "Missing download state for task."
                )
            }

            if let allowedContentTypes = state.allowedContentTypes {
                let rawContentType = httpResponse.value(
                    forHTTPHeaderField: "Content-Type"
                )
                guard let normalized = policy.normalizedContentType(
                    rawContentType
                ),
                allowedContentTypes.contains(normalized) else {
                    return WebToolError.unsupportedContentType(
                        rawContentType
                    )
                }
            }

            state.response = httpResponse
            return nil
        }

        if let validationError {
            fail(
                taskID: dataTask.taskIdentifier,
                error: validationError
            )
            completionHandler(.cancel)
            dataTask.cancel()
            return
        }

        completionHandler(.allow)
    }

    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        _ = session

        let failure: WebToolError? = stateQueue.sync {
            guard let state = states[dataTask.taskIdentifier] else {
                return nil
            }

            state.body.append(data)

            if state.body.count > state.maxBytes {
                return .responseTooLarge(
                    limit: state.maxBytes,
                    actual: state.body.count
                )
            }

            return nil
        }

        if let failure {
            fail(
                taskID: dataTask.taskIdentifier,
                error: failure
            )
            dataTask.cancel()
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        _ = session
        _ = response

        guard let redirectedURL = request.url else {
            fail(
                taskID: task.taskIdentifier,
                error: WebToolError.invalidURL(
                    "<missing redirect url>"
                )
            )
            completionHandler(nil)
            return
        }

        do {
            _ = try policy.validate(
                urlString: redirectedURL.absoluteString
            )
        } catch {
            fail(
                taskID: task.taskIdentifier,
                error: error
            )
            completionHandler(nil)
            return
        }

        let exceededRedirectLimit = stateQueue.sync { () -> Bool in
            guard let state = states[task.taskIdentifier] else {
                return true
            }

            state.redirectCount += 1
            return state.redirectCount > policy.maxRedirectCount
        }

        if exceededRedirectLimit {
            fail(
                taskID: task.taskIdentifier,
                error: WebToolError.tooManyRedirects(
                    limit: policy.maxRedirectCount
                )
            )
            completionHandler(nil)
            return
        }

        completionHandler(request)
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        _ = session

        if let error {
            fail(
                taskID: task.taskIdentifier,
                error: WebToolError.transportFailure(
                    error.localizedDescription
                )
            )
            return
        }

        finishSuccess(
            taskID: task.taskIdentifier
        )
    }
}

private extension IncrementalURLSessionDownloader {
    func finishSuccess(
        taskID: Int
    ) {
        let state: DownloadState? = stateQueue.sync {
            guard let state = states.removeValue(
                forKey: taskID
            ) else {
                return nil
            }

            guard !state.completed else {
                return nil
            }

            state.completed = true
            return state
        }

        guard let state else {
            return
        }

        guard let response = state.response else {
            state.continuation.resume(
                throwing: WebToolError.transportFailure(
                    "Completed without HTTP response."
                )
            )
            return
        }

        state.continuation.resume(
            returning: .init(
                response: response,
                body: state.body
            )
        )
    }

    func fail(
        taskID: Int,
        error: Error
    ) {
        let state: DownloadState? = stateQueue.sync {
            guard let state = states.removeValue(
                forKey: taskID
            ) else {
                return nil
            }

            guard !state.completed else {
                return nil
            }

            state.completed = true
            return state
        }

        state?.continuation.resume(
            throwing: error
        )
    }
}
