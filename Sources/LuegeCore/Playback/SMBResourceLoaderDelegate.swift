import AVFoundation
import Foundation

/// Custom URL scheme for SMB resource loading
public enum SMBResourceLoader {
    /// Custom URL scheme used for AVAssetResourceLoader
    public static let scheme = "smb-luege"

    /// Create a custom URL for SMB resource loading
    /// - Parameters:
    ///   - host: The SMB server hostname/IP
    ///   - share: The share name
    ///   - path: Path to the file within the share
    /// - Returns: Custom URL for use with AVAssetResourceLoader
    public static func makeURL(host: String, share: String, path: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        // Encode the share and path together
        let fullPath = path.hasPrefix("/") ? "/\(share)\(path)" : "/\(share)/\(path)"
        components.path = fullPath
        return components.url
    }

    /// Parse a custom URL to extract SMB path components
    /// - Parameter url: The custom URL
    /// - Returns: Tuple of (host, share, path) if valid
    public static func parseURL(_ url: URL) -> (host: String, share: String, path: String)? {
        guard url.scheme == scheme,
              let host = url.host,
              !host.isEmpty else {
            return nil
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count >= 1 else {
            return nil
        }

        let share = pathComponents[0]
        let remainingPath = pathComponents.dropFirst().joined(separator: "/")

        return (host, share, remainingPath)
    }
}

/// AVAssetResourceLoaderDelegate that bridges SMB file reads to AVPlayer
public final class SMBResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {

    private let fileReader: any SMBFileReading
    private let share: SavedShare
    private let credentials: ShareCredentials?

    // Cache file info to avoid repeated queries
    private var fileSizeCache: [String: Int64] = [:]
    private let queue = DispatchQueue(label: "com.luege.resourceloader", qos: .userInitiated)

    // Track pending requests for cancellation
    private var pendingTasks: [AVAssetResourceLoadingRequest: Task<Void, Never>] = [:]
    private let pendingTasksLock = NSLock()

    public init(
        fileReader: any SMBFileReading,
        share: SavedShare,
        credentials: ShareCredentials?
    ) {
        self.fileReader = fileReader
        self.share = share
        self.credentials = credentials
        super.init()
    }

    // MARK: - AVAssetResourceLoaderDelegate

    public func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        print("[ResourceLoader] shouldWaitForLoading called")
        print("[ResourceLoader] URL: \(loadingRequest.request.url?.absoluteString ?? "nil")")

        guard let url = loadingRequest.request.url,
              url.scheme == SMBResourceLoader.scheme else {
            print("[ResourceLoader] Scheme mismatch, returning false")
            return false
        }

        // Parse the custom URL to get the file path
        guard let (host, share, path) = SMBResourceLoader.parseURL(url) else {
            print("[ResourceLoader] Failed to parse URL")
            loadingRequest.finishLoading(with: PlaybackError.fileNotFound("Invalid URL"))
            return true
        }
        print("[ResourceLoader] Parsed - host: \(host), share: \(share), path: \(path)")

        // Create a task to handle this request
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.handleLoadingRequest(loadingRequest, path: path)
        }

        // Store the task for potential cancellation
        pendingTasksLock.lock()
        pendingTasks[loadingRequest] = task
        pendingTasksLock.unlock()

        return true
    }

    public func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        // Cancel the associated task
        pendingTasksLock.lock()
        if let task = pendingTasks.removeValue(forKey: loadingRequest) {
            task.cancel()
        }
        pendingTasksLock.unlock()
    }

    // MARK: - Request Handling

    private func handleLoadingRequest(_ loadingRequest: AVAssetResourceLoadingRequest, path: String) async {
        print("[ResourceLoader] handleLoadingRequest for path: \(path)")

        // Check for cancellation
        guard !Task.isCancelled else {
            print("[ResourceLoader] Task cancelled")
            cleanupRequest(loadingRequest)
            return
        }

        // Ensure connected
        if !fileReader.isConnected {
            print("[ResourceLoader] Not connected, connecting...")
            do {
                try await fileReader.connect(to: share, credentials: credentials)
                print("[ResourceLoader] Connected successfully")
            } catch {
                print("[ResourceLoader] Connection error: \(error)")
                loadingRequest.finishLoading(with: error)
                cleanupRequest(loadingRequest)
                return
            }
        } else {
            print("[ResourceLoader] Already connected")
        }

        // Handle content information request
        if let contentInfoRequest = loadingRequest.contentInformationRequest {
            print("[ResourceLoader] Handling content info request")
            do {
                try await handleContentInfoRequest(contentInfoRequest, path: path)
                print("[ResourceLoader] Content info request completed")
            } catch {
                print("[ResourceLoader] Content info error: \(error)")
                loadingRequest.finishLoading(with: error)
                cleanupRequest(loadingRequest)
                return
            }
        }

        // Handle data request
        if let dataRequest = loadingRequest.dataRequest {
            print("[ResourceLoader] Handling data request: offset=\(dataRequest.requestedOffset), length=\(dataRequest.requestedLength)")
            do {
                try await handleDataRequest(dataRequest, path: path)
                print("[ResourceLoader] Data request completed")
            } catch {
                print("[ResourceLoader] Data request error: \(error)")
                loadingRequest.finishLoading(with: error)
                cleanupRequest(loadingRequest)
                return
            }
        }

        // Finish successfully
        print("[ResourceLoader] Finishing loading request successfully")
        loadingRequest.finishLoading()
        cleanupRequest(loadingRequest)
    }

    private func handleContentInfoRequest(
        _ request: AVAssetResourceLoadingContentInformationRequest,
        path: String
    ) async throws {
        // Get file size (use cache if available)
        let fileSize: Int64
        if let cached = fileSizeCache[path] {
            print("[ResourceLoader] Using cached file size: \(cached)")
            fileSize = cached
        } else {
            print("[ResourceLoader] Fetching file size for: \(path)")
            fileSize = try await fileReader.fileSize(at: path)
            print("[ResourceLoader] File size: \(fileSize) bytes")
            fileSizeCache[path] = fileSize
        }

        // Set content information
        request.contentLength = fileSize
        request.isByteRangeAccessSupported = true

        // Determine content type from file extension
        let fileExtension = (path as NSString).pathExtension.lowercased()
        let contentTypeStr = contentType(for: fileExtension)
        request.contentType = contentTypeStr
        print("[ResourceLoader] Content type: \(contentTypeStr) for extension: \(fileExtension)")
    }

    private func handleDataRequest(
        _ request: AVAssetResourceLoadingDataRequest,
        path: String
    ) async throws {
        let requestedOffset = request.requestedOffset
        var currentOffset = request.currentOffset
        let requestedLength = Int64(request.requestedLength)

        // Calculate how much data we still need to provide
        let remainingLength = requestedLength - (currentOffset - requestedOffset)

        guard remainingLength > 0 else { return }

        // Read data in chunks to support cancellation
        let chunkSize: Int64 = 512 * 1024 // 512 KB chunks
        var bytesRemaining = remainingLength

        while bytesRemaining > 0 && !Task.isCancelled {
            let bytesToRead = min(chunkSize, bytesRemaining)
            let range = currentOffset..<(currentOffset + bytesToRead)

            let data = try await fileReader.readData(at: path, range: range)
            request.respond(with: data)

            currentOffset += Int64(data.count)
            bytesRemaining -= Int64(data.count)
        }
    }

    private func cleanupRequest(_ request: AVAssetResourceLoadingRequest) {
        pendingTasksLock.lock()
        pendingTasks.removeValue(forKey: request)
        pendingTasksLock.unlock()
    }

    // MARK: - Content Type Detection

    private func contentType(for fileExtension: String) -> String {
        // AVPlayer needs UTI types, not MIME types
        switch fileExtension {
        case "mp4":
            return "public.mpeg-4"
        case "m4v":
            return "com.apple.m4v-video"
        case "mov":
            return "com.apple.quicktime-movie"
        case "mkv":
            // MKV is not natively supported by AVPlayer, but we'll try
            return "public.mpeg-4" // Fallback to mp4 UTI
        case "avi":
            return "public.avi"
        case "wmv":
            return "com.microsoft.windows-media-wmv"
        case "ts":
            return "public.mpeg-2-transport-stream"
        case "webm":
            return "public.mpeg-4" // WebM not natively supported, fallback
        default:
            return "public.movie"
        }
    }
}
