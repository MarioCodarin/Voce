import Foundation

/// Shared, conservative URLSession: no cache, no cookie sharing, bounded connections.
/// Uploads stream from disk, so memory stays flat regardless of file size.
enum NetworkSession {
    static let shared: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = TranscriptionConfig.requestTimeout
        configuration.timeoutIntervalForResource = TranscriptionConfig.requestTimeout + 60
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = 2
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }()
}
