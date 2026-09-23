import Foundation
import MusicDomain
import MusicLibrary

/// The transport owns only completed temporary files. A PCM decode session
/// removes its file when playback, prefetch, or a stale resolution closes it.
public nonisolated protocol RemoteAudioDownloading: Sendable {
    func download(_ url: URL) async throws -> URL
    func remove(_ url: URL) async
}

public actor RemoteAudioDownloadStore: RemoteAudioDownloading {
    private let session: URLSession
    private let directory: URL

    public init(
        session: URLSession = .shared,
        directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MSRU-PreparedAudio", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    ) {
        self.session = session
        self.directory = directory
    }

    public func download(_ url: URL) async throws -> URL {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            throw RemoteAudioDownloadError.invalidURL
        }
        let (temporaryURL, response) = try await session.download(from: url)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else {
            throw RemoteAudioDownloadError.invalidResponse
        }
        switch http.statusCode {
        case 200: break
        case 401, 403: throw RemoteAudioDownloadError.authenticationFailed
        default: throw RemoteAudioDownloadError.serverStatus(http.statusCode)
        }
        let mime = http.mimeType?.lowercased() ?? ""
        guard !mime.hasPrefix("text/"), mime != "application/json", mime != "application/xml" else {
            throw RemoteAudioDownloadError.invalidAudioResponse
        }
        let fileExtension = Self.fileExtension(mime: mime, suggestedName: response.suggestedFilename)
        let destination = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        if Task.isCancelled {
            try? FileManager.default.removeItem(at: destination)
            throw CancellationError()
        }
        return destination
    }

    public func remove(_ url: URL) {
        guard url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private nonisolated static func fileExtension(mime: String, suggestedName: String?) -> String {
        switch mime {
        case "audio/flac", "audio/x-flac": return "flac"
        case "audio/mpeg", "audio/mp3": return "mp3"
        case "audio/wav", "audio/wave", "audio/x-wav": return "wav"
        case "audio/mp4", "audio/x-m4a": return "m4a"
        case "audio/aac": return "aac"
        case "audio/ogg": return "ogg"
        case "audio/opus": return "opus"
        case "audio/aiff", "audio/x-aiff": return "aiff"
        default:
            let proposed = URL(fileURLWithPath: suggestedName ?? "").pathExtension.lowercased()
            return ["flac", "mp3", "wav", "m4a", "aac", "ogg", "opus", "aiff"].contains(proposed)
                ? proposed : "audio"
        }
    }
}

public actor DownloadedPCMDecodeSession: PCMDecodeSession {
    private let wrapped: any PCMDecodeSession
    private let fileURL: URL
    private let downloadStore: any RemoteAudioDownloading
    private var isClosed = false

    public init(wrapped: any PCMDecodeSession, fileURL: URL, downloadStore: any RemoteAudioDownloading) {
        self.wrapped = wrapped
        self.fileURL = fileURL
        self.downloadStore = downloadStore
    }

    public func read(maxFrames: Int) async throws -> PCMFrameBlock? {
        guard !isClosed else { return nil }
        return try await wrapped.read(maxFrames: maxFrames)
    }

    public func seek(to seconds: TimeInterval) async throws {
        guard !isClosed else { return }
        try await wrapped.seek(to: seconds)
    }

    public func close() async {
        guard !isClosed else { return }
        isClosed = true
        await wrapped.close()
        await downloadStore.remove(fileURL)
    }
}

private enum RemoteAudioDownloadError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidAudioResponse
    case authenticationFailed
    case serverStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "The audio stream URL is invalid."
        case .invalidResponse: "The audio server returned no HTTP response."
        case .invalidAudioResponse: "The audio server returned a non-audio response."
        case .authenticationFailed: "The audio server rejected the playback credentials."
        case .serverStatus(let code): "The audio server returned HTTP \(code)."
        }
    }
}
