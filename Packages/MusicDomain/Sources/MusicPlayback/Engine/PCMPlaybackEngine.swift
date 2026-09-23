import AVFoundation
import Foundation
import MusicDomain
import MusicLibrary

/// One audio engine and one player node for a run of compatible PCM tracks.
/// The next track's first block is decoded early and scheduled immediately
/// after the final block of the current track, without stopping the node.
@MainActor
public final class PCMPlaybackEngine {
    public typealias EndHandler = @MainActor () -> Void
    public typealias FailureHandler = @MainActor (Error) -> Void
    public typealias AdvanceHandler = @MainActor (UUID, PlaybackResource) -> Void
    public typealias ConfigurationHandler = @MainActor () -> Void

    public var onEnded: EndHandler?
    public var onFailure: FailureHandler?
    public var onAdvanced: AdvanceHandler?
    public var onConfigurationChanged: ConfigurationHandler?

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let equalizerNode = AVAudioUnitEQ(numberOfBands: EqualizerState.frequencies.count)
    private let normalizationNode = AVAudioUnitEQ(numberOfBands: 1)
    private var configurationObserver: NSObjectProtocol?
    private let audioFormat: AVAudioFormat
    private var session: any PCMDecodeSession
    public private(set) var format: PCMStreamFormat

    private struct PreparedNext {
        public let queueID: UUID
        public let resource: PlaybackResource
        public let pcm: PCMPlaybackResource
        public let firstBlock: Task<PCMFrameBlock?, Error>
    }

    private struct PendingTransition {
        public let queueID: UUID
        public let resource: PlaybackResource
        public let format: PCMStreamFormat
        public let oldSession: any PCMDecodeSession
        public let oldFrameCount: Int64
    }

    private var preparedNext: PreparedNext?
    private var pendingTransition: PendingTransition?
    private var decodeTask: Task<Void, Never>?
    private var generation = 0
    private var trackSerial = 0
    private var decodingSerial = 0
    private var scheduledBufferCount = 0
    private var currentTrackBufferCount = 0
    private var currentTrackFrameCount: Int64 = 0
    private var nextTrackFrameCount: Int64 = 0
    private var trackStartSample: Int64 = 0
    private var decoderReachedEnd = false
    private var wantsToPlay = false
    private var baseTime: TimeInterval = 0
    private let maximumScheduledBuffers = 4
    private let decodeBlockFrames = 8192
    private var requestedVolume: Float = 1
    public private(set) var equalizerState = EqualizerState()
    private var isStartingOutput = false
    private var isSeeking = false

    public var outputSampleRate: Double { audioEngine.outputNode.outputFormat(forBus: 0).sampleRate }
    public var isOutputRunning: Bool { audioEngine.isRunning }
    public var renderedVolume: Float { playerNode.volume }
    public var equalizerBandGains: [Float] { equalizerNode.bands.map(\.gain) }
    public var equalizerIsBypassed: Bool { equalizerNode.bypass }
    public var replayGainDB: Float { normalizationNode.globalGain }

    public init(resource: PCMPlaybackResource, outputDeviceID: UInt32? = nil,
         equalizer: EqualizerState = EqualizerState(), initialTime: TimeInterval = 0,
         replayGainDB: Float = 0) async throws {
        session = resource.session
        format = resource.format
        baseTime = max(0, initialTime)
        guard let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: resource.format.sampleRate,
            channels: AVAudioChannelCount(resource.format.channels),
            interleaved: false
        ) else {
            throw PCMPlaybackEngineError.invalidAudioFormat
        }
        self.audioFormat = audioFormat
        audioEngine.attach(playerNode)
        audioEngine.attach(equalizerNode)
        audioEngine.attach(normalizationNode)
        normalizationNode.bands[0].bypass = true
        normalizationNode.globalGain = replayGainDB
        for (index, frequency) in EqualizerState.frequencies.enumerated() {
            let band = equalizerNode.bands[index]
            band.filterType = .parametric
            band.frequency = min(frequency, Float(resource.format.sampleRate * 0.45))
            band.bandwidth = 1
            band.bypass = false
        }
        if #available(macOS 27.0, iOS 27.0, tvOS 27.0, watchOS 27.0, *) {
            try audioEngine.connectNode(playerNode, to: equalizerNode, format: audioFormat)
            try audioEngine.connectNode(equalizerNode, to: normalizationNode, format: audioFormat)
            try audioEngine.connectNode(normalizationNode, to: audioEngine.mainMixerNode, format: audioFormat)
        } else {
            audioEngine.connect(playerNode, to: equalizerNode, format: audioFormat)
            audioEngine.connect(equalizerNode, to: normalizationNode, format: audioFormat)
            audioEngine.connect(normalizationNode, to: audioEngine.mainMixerNode, format: audioFormat)
        }
        applyEqualizer(equalizer)
        audioEngine.prepare()
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: audioEngine, queue: nil
        ) { [weak self] _ in
            // AVAudioEngine posts this from an internal queue. Defer rebuilding to the owner.
            Task { @MainActor [weak self] in
                guard let self, self.configurationObserver != nil else { return }
                try? await Task.sleep(for: .milliseconds(80))
                guard !self.isStartingOutput, !self.isSeeking,
                      !self.audioEngine.isRunning else { return }
                self.onConfigurationChanged?()
            }
        }
        do {
            try await startOutput(deviceID: outputDeviceID)
        } catch {
            if let configurationObserver {
                NotificationCenter.default.removeObserver(configurationObserver)
                self.configurationObserver = nil
            }
            audioEngine.stop()
            throw error
        }
    }

    private func startOutput(deviceID: UInt32?) async throws {
        isStartingOutput = true
        defer { isStartingOutput = false }
        var lastError: Error?
        for attempt in 0..<3 {
            try Task.checkCancellation()
            do {
                if !audioEngine.isRunning {
                    #if os(macOS)
                    try audioEngine.routeToMacOutput(deviceID: deviceID)
                    #endif
                    try audioEngine.start()
                }
                // A routed output can report start success before its HAL format settles.
                try await Task.sleep(for: .milliseconds(deviceID == nil ? 30 : 140))
                if audioEngine.isRunning { return }
                lastError = PCMPlaybackEngineError.outputStopped
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
            if attempt < 2 { try await Task.sleep(for: .milliseconds(120)) }
        }
        throw lastError ?? PCMPlaybackEngineError.outputStopped
    }

    public var isPlaying: Bool { wantsToPlay && playerNode.isPlaying }
    public var hasPendingTransition: Bool { pendingTransition != nil }
    public var duration: TimeInterval { format.duration ?? 0 }
    public var volume: Float {
        get { requestedVolume }
        set {
            requestedVolume = min(max(newValue, 0), 1)
            playerNode.volume = requestedVolume
        }
    }

    public func applyEqualizer(_ state: EqualizerState) {
        var normalized = state
        normalized.sanitize()
        equalizerState = normalized
        equalizerNode.bypass = !normalized.isEnabled
        for (band, gain) in zip(equalizerNode.bands, normalized.gains) {
            band.gain = gain
        }
        playerNode.volume = requestedVolume
    }

    public func setReplayGainDB(_ gain: Float) {
        normalizationNode.globalGain = gain.isFinite ? min(max(gain, -30), 18) : 0
    }

    public var currentTime: TimeInterval {
        guard let renderTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: renderTime) else {
            return baseTime
        }
        let elapsed = Double(max(0, playerTime.sampleTime - trackStartSample)) / playerTime.sampleRate
        let value = baseTime + elapsed
        return duration > 0 ? min(value, duration) : value
    }

    public func play() {
        wantsToPlay = true
        if decodeTask == nil && !decoderReachedEnd { beginDecoding() }
        if scheduledBufferCount > 0 && !playerNode.isPlaying { startPlayerNode() }
    }

    public func pause() {
        wantsToPlay = false
        playerNode.pause()
    }

    public func seek(to seconds: TimeInterval) async throws {
        let clamped = duration > 0 ? min(max(0, seconds), duration) : max(0, seconds)
        isSeeking = true
        defer { isSeeking = false }
        generation += 1
        decodeTask?.cancel()
        decodeTask = nil
        clearPreparedNext()
        let shouldRestartOutput = audioEngine.isRunning
        if shouldRestartOutput { audioEngine.pause() }
        playerNode.stop()
        scheduledBufferCount = 0
        currentTrackBufferCount = 0
        currentTrackFrameCount = 0
        nextTrackFrameCount = 0
        trackStartSample = 0
        decoderReachedEnd = false
        baseTime = clamped
        decodingSerial = trackSerial
        if let pendingTransition {
            self.pendingTransition = nil
            let nextSession = session
            session = pendingTransition.oldSession
            await nextSession.close()
        }
        try await session.seek(to: clamped)
        if shouldRestartOutput { try audioEngine.start() }
        beginDecoding()
    }

    public func close() async {
        generation += 1
        decodeTask?.cancel()
        decodeTask = nil
        clearPreparedNext()
        wantsToPlay = false
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
        audioEngine.stop()
        playerNode.stop()
        if let pendingTransition {
            self.pendingTransition = nil
            await pendingTransition.oldSession.close()
        }
        await session.close()
    }

    public func canPrepare(_ resource: PlaybackResource) -> Bool {
        guard case .decodedPCM(let pcm) = resource.transport else { return false }
        return pcm.format.sampleRate == audioFormat.sampleRate
            && pcm.format.channels == audioFormat.channelCount
    }

    public func prepareNext(queueID: UUID, resource: PlaybackResource) {
        guard case .decodedPCM(let pcm) = resource.transport, canPrepare(resource) else { return }
        clearPreparedNext()
        let firstBlock = Task { try await pcm.session.read(maxFrames: decodeBlockFrames) }
        preparedNext = PreparedNext(queueID: queueID, resource: resource, pcm: pcm, firstBlock: firstBlock)
        if decoderReachedEnd && decodeTask == nil && scheduledBufferCount > 0 {
            beginDecoding()
        }
    }

    public func clearPreparedNext() {
        guard let preparedNext else { return }
        self.preparedNext = nil
        preparedNext.firstBlock.cancel()
        Task { await preparedNext.pcm.session.close() }
    }

    private func beginDecoding() {
        let activeGeneration = generation
        decoderReachedEnd = false
        decodeTask = Task { [weak self] in
            await self?.decodeLoop(generation: activeGeneration)
        }
    }

    private func decodeLoop(generation: Int) async {
        while !Task.isCancelled && generation == self.generation {
            while scheduledBufferCount >= maximumScheduledBuffers {
                do { try await Task.sleep(nanoseconds: 5_000_000) }
                catch { return }
                guard generation == self.generation else { return }
            }
            do {
                guard let block = try await session.read(maxFrames: decodeBlockFrames) else {
                    if let next = preparedNext {
                        preparedNext = nil
                        do {
                            let first = try await next.firstBlock.value
                            guard generation == self.generation && !Task.isCancelled else {
                                await next.pcm.session.close()
                                return
                            }
                            if let first, first.frameCount > 0 {
                                pendingTransition = PendingTransition(
                                    queueID: next.queueID,
                                    resource: next.resource,
                                    format: next.pcm.format,
                                    oldSession: session,
                                    oldFrameCount: currentTrackFrameCount
                                )
                                session = next.pcm.session
                                decodingSerial += 1
                                decoderReachedEnd = false
                                try schedule(first, generation: generation, serial: decodingSerial)
                                if currentTrackBufferCount == 0 { completeTransition() }
                                continue
                            }
                            await next.pcm.session.close()
                        } catch {
                            await next.pcm.session.close()
                        }
                    }
                    decoderReachedEnd = true
                    decodeTask = nil
                    if scheduledBufferCount == 0 { finishPlayback() }
                    return
                }
                guard generation == self.generation && !Task.isCancelled else { return }
                try schedule(block, generation: generation, serial: decodingSerial)
            } catch is CancellationError {
                return
            } catch {
                guard generation == self.generation else { return }
                decodeTask = nil
                wantsToPlay = false
                playerNode.stop()
                onFailure?(error)
                return
            }
        }
    }

    private func schedule(_ block: PCMFrameBlock, generation: Int, serial: Int) throws {
        guard block.frameCount > 0 else { return }
        guard block.channels.count == Int(audioFormat.channelCount),
              block.channels.allSatisfy({ $0.count >= block.frameCount }) else {
            throw PCMPlaybackEngineError.invalidPCMBlock
        }
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: AVAudioFrameCount(block.frameCount)
        ), let floatData = buffer.floatChannelData else {
            throw PCMPlaybackEngineError.bufferAllocationFailed
        }
        buffer.frameLength = AVAudioFrameCount(block.frameCount)
        for channel in block.channels.indices {
            block.channels[channel].withUnsafeBufferPointer { source in
                if let base = source.baseAddress {
                    memcpy(floatData[channel], base, block.frameCount * MemoryLayout<Float>.size)
                }
            }
        }
        scheduledBufferCount += 1
        if serial == trackSerial {
            currentTrackBufferCount += 1
            currentTrackFrameCount += Int64(block.frameCount)
        } else {
            nextTrackFrameCount += Int64(block.frameCount)
        }
        playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bufferDidFinish(generation: generation, serial: serial)
            }
        }
        if wantsToPlay && !playerNode.isPlaying { startPlayerNode() }
    }

    private func startPlayerNode() {
        guard audioEngine.isRunning else {
            if let onConfigurationChanged { onConfigurationChanged() }
            else { onFailure?(PCMPlaybackEngineError.outputStopped) }
            return
        }
        if #available(macOS 27.0, iOS 27.0, tvOS 27.0, watchOS 27.0, *) {
            do { try playerNode.playAudio() }
            catch { onFailure?(error) }
        } else {
            playerNode.play()
        }
    }

    private func bufferDidFinish(generation: Int, serial: Int) {
        guard generation == self.generation else { return }
        scheduledBufferCount = max(0, scheduledBufferCount - 1)
        if serial == trackSerial {
            currentTrackBufferCount = max(0, currentTrackBufferCount - 1)
            if currentTrackBufferCount == 0 && pendingTransition != nil { completeTransition() }
        }
        if decoderReachedEnd && scheduledBufferCount == 0 { finishPlayback() }
    }

    private func completeTransition() {
        guard let transition = pendingTransition else { return }
        pendingTransition = nil
        trackSerial += 1
        trackStartSample += transition.oldFrameCount
        baseTime = 0
        format = transition.format
        currentTrackFrameCount = nextTrackFrameCount
        nextTrackFrameCount = 0
        currentTrackBufferCount = scheduledBufferCount
        Task { await transition.oldSession.close() }
        onAdvanced?(transition.queueID, transition.resource)
    }

    private func finishPlayback() {
        wantsToPlay = false
        baseTime = duration > 0 ? duration : currentTime
        onEnded?()
    }
}

private enum PCMPlaybackEngineError: LocalizedError {
    case invalidAudioFormat
    case invalidPCMBlock
    case bufferAllocationFailed
    case outputStopped

    public var errorDescription: String? {
        switch self {
        case .invalidAudioFormat: "Unable to create the PCM playback format."
        case .invalidPCMBlock: "The decoder returned an invalid PCM block."
        case .bufferAllocationFailed: "Unable to allocate an AVAudioPCMBuffer."
        case .outputStopped: "The audio output stopped before playback could begin."
        }
    }
}
