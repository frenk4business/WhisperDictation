import Foundation

/// Context passed to the C callback for streaming segment output.
/// Retained via Unmanaged for the duration of whisper_full.
private final class SegmentCallbackContext {
    let onSegment: (String) -> Void

    init(onSegment: @escaping (String) -> Void) {
        self.onSegment = onSegment
    }
}

/// C-compatible callback for new_segment_callback
private func segmentCallback(
    _ ctx: OpaquePointer?,
    _ state: OpaquePointer?,
    _ nNew: Int32,
    _ userData: UnsafeMutableRawPointer?
) {
    guard let userData, let ctx else { return }
    let callbackCtx = Unmanaged<SegmentCallbackContext>.fromOpaque(userData).takeUnretainedValue()

    let totalSegments = whisper_full_n_segments(ctx)
    let start = max(0, totalSegments - nNew)
    for i in start..<totalSegments {
        if let text = whisper_full_get_segment_text(ctx, i) {
            let segment = String(cString: text).trimmingCharacters(in: .whitespaces)
            if !segment.isEmpty {
                callbackCtx.onSegment(segment)
            }
        }
    }
}

/// Thread-safe cancellation signal shared with the ggml `abort_callback`. The whisper
/// compute threads poll `isCancelled` (read frequently, so kept lock-cheap); the main
/// actor flips it via `cancel()`.
final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _cancelled = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return _cancelled }
    func cancel() { lock.lock(); _cancelled = true; lock.unlock() }
}

/// C-compatible ggml abort callback. Returns true to abort the compute graph.
/// `user_data` is the opaque pointer to the active `CancellationFlag`.
private func abortCallback(_ userData: UnsafeMutableRawPointer?) -> Bool {
    guard let userData else { return false }
    return Unmanaged<CancellationFlag>.fromOpaque(userData).takeUnretainedValue().isCancelled
}

final class WhisperBridge: @unchecked Sendable {
    struct Transcription: Sendable {
        let text: String
        let detectedLanguage: String?
    }
    private let context: OpaquePointer
    private let queue = DispatchQueue(label: "com.whisperdictation.whisper", qos: .userInitiated)
    private let vadModelPath: String?

    /// True once `shutdownAndFree()` has freed `context`. Written and read only on
    /// `queue` (the same serialization that protects every context access), except
    /// in deinit, where no other references — and hence no concurrent queue work
    /// started after the free — can exist.
    private var freed = false

    /// The cancellation flag for the currently in-flight `transcribe`, if any. Guarded
    /// by `cancelLock`. Set when `transcribe` is entered (so a cancel arriving during
    /// the multi-second decode reaches it) and cleared when that decode finishes.
    private let cancelLock = NSLock()
    private var activeCancelFlag: CancellationFlag?

    private static var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    init(modelPath: String) throws {
        var contextParams = whisper_context_default_params()
        contextParams.use_gpu = Self.isAppleSilicon
        contextParams.flash_attn = Self.isAppleSilicon

        fputs("[WhisperBridge] Loading model: \(modelPath)\n", stderr)

        guard let ctx = whisper_init_from_file_with_params(modelPath, contextParams) else {
            throw WhisperError.modelLoadFailed(modelPath)
        }
        self.context = ctx

        let vadPath = ModelManager.shared.vadModelPath()
        self.vadModelPath = vadPath
        fputs("[WhisperBridge] Model loaded | GPU: \(Self.isAppleSilicon) | VAD: \(vadPath != nil)\n", stderr)
    }

    deinit {
        if !freed { whisper_free(context) }
    }

    // MARK: - GPU Pre-warming

    /// Run a tiny dummy inference to JIT-compile Metal shaders.
    /// Call once after model load so the first real inference isn't slower.
    /// Async so the caller's thread (a cooperative-pool task) is released during
    /// the warmup inference instead of being blocked by `queue.sync`.
    func warmup(language: SpeechLanguage = .english) async {
        await withCheckedContinuation { continuation in
            queue.async {
                guard !self.freed else {
                    continuation.resume()
                    return
                }
                let silence = [Float](repeating: 0, count: 8000) // 0.5s of silence
                var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
                params.n_threads = 1
                params.single_segment = true
                params.no_context = true
                guard language == .english || whisper_is_multilingual(self.context) != 0 else {
                    continuation.resume()
                    return
                }
                let langCStr = strdup(language.rawValue)
                params.language = UnsafePointer(langCStr)
                defer { free(langCStr) }

                silence.withUnsafeBufferPointer { ptr in
                    _ = whisper_full(self.context, params, ptr.baseAddress, Int32(silence.count))
                }
                fputs("[WhisperBridge] GPU pre-warmed\n", stderr)
                continuation.resume()
            }
        }
    }

    // MARK: - Streaming Transcription

    /// Transcribe with streaming: calls `onSegment` as each text segment is decoded,
    /// and returns the full concatenated transcription when complete.
    ///
    /// Async entry point: bridges the synchronous, queue-bound inference to async so
    /// the calling cooperative-pool task is released for the multi-second decode
    /// instead of being blocked. All whisper C calls still run on `queue`.
    ///
    /// Throws `WhisperError.transcriptionFailed` on a non-zero `whisper_full` status,
    /// or `WhisperError.cancelled` if `cancelTranscription()` aborted the decode.
    ///
    /// Pass `cancelFlag` to drive cancellation from outside; omit it (the default) and
    /// each call gets its own flag. An external flag may be *shared* across several
    /// queued `transcribe` calls (live sessions do this, so one flip cancels the whole
    /// session). `cancelTranscription()` still only targets the most recent call's flag —
    /// live callers cancel by flipping the shared flag directly.
    ///
    /// `vad: false` skips whisper's internal VAD for this call only.
    func transcribe(
        audioBuffer: [Float],
        language: SpeechLanguage = .english,
        prompt: String = "",
        cancelFlag externalFlag: CancellationFlag? = nil,
        vad: Bool = true,
        onSegment: (@Sendable (String) -> Void)? = nil
    ) async throws -> Transcription {
        let cancelFlag = externalFlag ?? CancellationFlag()
        setActiveCancelFlag(cancelFlag)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Transcription, Error>) in
            queue.async {
                defer { self.clearActiveCancelFlag(ifCurrent: cancelFlag) }
                guard !self.freed else {
                    // Context freed during app termination: surface as the benign
                    // cancel path every caller already handles.
                    continuation.resume(throwing: WhisperError.cancelled)
                    return
                }
                do {
                    let result = try self.runInference(audioBuffer: audioBuffer, language: language, prompt: prompt, vadEnabled: vad, onSegment: onSegment, cancelFlag: cancelFlag)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Request cancellation of the in-flight transcription (if any). Idempotent and
    /// safe to call from any thread. A no-op when nothing is running. The aborted
    /// `transcribe` throws `WhisperError.cancelled`; already-decoded segments that were
    /// already typed remain.
    func cancelTranscription() {
        cancelLock.lock()
        let flag = activeCancelFlag
        cancelLock.unlock()
        flag?.cancel()
    }

    /// Cancel any in-flight decode, then free the whisper context on the serial
    /// queue — deterministically, regardless of who still holds references to the
    /// bridge (a live-session consumer task keeps one across the whole session, so
    /// waiting for refcounted deinit is not an option at exit, and blocking on the
    /// consumer would deadlock: it finishes on the main actor). Needed because
    /// NSApplication's terminate path calls exit() without running Swift deinits,
    /// and ggml's Metal teardown asserts at exit (ggml_metal_rsets_free) if any
    /// context's Metal resources are still alive. Queue blocks that touch the
    /// context check `freed` first, so late transcribe calls fail as cancelled
    /// instead of touching freed memory. Idempotent; called on the main thread
    /// during app termination.
    func shutdownAndFree() {
        cancelTranscription()
        queue.sync {
            guard !self.freed else { return }
            self.freed = true
            whisper_free(self.context)
        }
    }

    // Synchronous lock helpers. Kept out of the async `transcribe` body so the NSLock
    // is never taken across a suspension point (which the compiler forbids).
    private func setActiveCancelFlag(_ flag: CancellationFlag) {
        cancelLock.lock()
        activeCancelFlag = flag
        cancelLock.unlock()
    }

    private func clearActiveCancelFlag(ifCurrent flag: CancellationFlag) {
        cancelLock.lock()
        if activeCancelFlag === flag { activeCancelFlag = nil }
        cancelLock.unlock()
    }

    /// Synchronous inference body. MUST be called on `queue` — the whisper C context
    /// is only ever touched from that queue (thread-safety contract). Extracted from
    /// the former `queue.sync` closure so `transcribe` can bridge it to async.
    private func runInference(
        audioBuffer: [Float],
        language: SpeechLanguage,
        prompt: String,
        vadEnabled: Bool,
        onSegment: (@Sendable (String) -> Void)?,
        cancelFlag: CancellationFlag
    ) throws -> Transcription {
        dispatchPrecondition(condition: .onQueue(queue))
        guard language == .english || whisper_is_multilingual(context) != 0 else {
            throw WhisperError.incompatibleLanguage
        }
        guard !cancelFlag.isCancelled else { throw WhisperError.cancelled }
        let startTime = CFAbsoluteTimeGetCurrent()
        let audioDuration = Double(audioBuffer.count) / 16000.0

        // Adaptive decoding: greedy for short clips (<2s), beam search for longer
        let useBeamSearch = Self.isAppleSilicon && audioBuffer.count >= 32000
        var params = useBeamSearch
            ? whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH)
            : whisper_full_default_params(WHISPER_SAMPLING_GREEDY)

        if useBeamSearch {
            params.beam_search.beam_size = 5
        }

        // Allocate C strings (freed in defer)
        let langCStr = strdup(language.rawValue)
        // Preserve the legacy English filter only for explicit English dictation.
        let suppressCStr = language == .english ? strdup("(Thank you|Thanks for watching|Please subscribe|you)") : nil
        var vadPathCStr: UnsafeMutablePointer<CChar>?

        params.language = UnsafePointer(langCStr)
        params.translate = false
        params.suppress_nst = true
        params.suppress_regex = suppressCStr.map { UnsafePointer($0) }
        // "auto" detects AND transcribes. detect_language=true would return after detection.
        params.detect_language = false
        // true = each transcription is independent (prevents hallucination carry-over)
        params.no_context = true

        // Must be false for streaming — allows multiple segment callbacks during decode
        params.single_segment = false

        // Temperature fallback (disable for beam search — causes unexpected re-decodes)
        params.temperature = 0.0
        params.temperature_inc = useBeamSearch ? 0.0 : 0.2
        params.entropy_thold = 2.4
        params.logprob_thold = -1.0
        params.no_speech_thold = 0.6

        // Threads
        let threadCount = Self.isAppleSilicon
            ? max(1, ProcessInfo.processInfo.activeProcessorCount - 2)
            : max(1, ProcessInfo.processInfo.activeProcessorCount)
        params.n_threads = Int32(threadCount)

        // VAD — skippable per call: live-mode chunks are already speech-trimmed
        // by the segmenter, and whisper's internal VAD defaults (250 ms min
        // speech) can silently discard a barely-min chunk.
        if vadEnabled, let vadPath = self.vadModelPath {
            params.vad = true
            vadPathCStr = strdup(vadPath)
            params.vad_model_path = UnsafePointer(vadPathCStr)
        }

        // Vocabulary prompt
        // The pinned decoder retains at most half the model's text context (224
        // tokens for these models), not a guessed number of words. Tokenize here
        // and retain the tail, where custom terms/recent speech are placed.
        let boundedPrompt = String(prompt.prefix(32_768))
        let required = boundedPrompt.withCString { -whisper_tokenize(context, $0, nil, 0) }
        var promptTokens = [whisper_token](repeating: 0, count: Int(max(0, required)))
        if !promptTokens.isEmpty {
            let count = promptTokens.withUnsafeMutableBufferPointer { buffer in
                boundedPrompt.withCString { whisper_tokenize(context, $0, buffer.baseAddress, Int32(buffer.count)) }
            }
            if count > 0 { promptTokens = Array(promptTokens.prefix(Int(count)).suffix(Int(whisper_n_text_ctx(context) / 2))) }
            else { promptTokens = [] }
        }
        params.initial_prompt = nil

        // Streaming callback setup
        var callbackCtxPtr: Unmanaged<SegmentCallbackContext>?
        if let onSegment {
            let ctx = SegmentCallbackContext(onSegment: onSegment)
            let ptr = Unmanaged.passRetained(ctx)
            callbackCtxPtr = ptr
            params.new_segment_callback = segmentCallback
            params.new_segment_callback_user_data = ptr.toOpaque()
        }

        // Abort callback: lets the main actor cancel a long decode. Retained for the
        // duration of whisper_full and released in defer (same Unmanaged pattern as
        // the segment callback).
        let cancelCtxPtr = Unmanaged.passRetained(cancelFlag)
        params.abort_callback = abortCallback
        params.abort_callback_user_data = cancelCtxPtr.toOpaque()

        defer {
            free(langCStr)
            free(suppressCStr)
            if let v = vadPathCStr { free(v) }
            callbackCtxPtr?.release()
            cancelCtxPtr.release()
        }

        let strategy = useBeamSearch ? "beam(5)" : "greedy"
        fputs("[WhisperBridge] \(String(format: "%.1f", audioDuration))s | \(strategy) | \(threadCount)T | streaming: \(onSegment != nil)\n", stderr)

        let result = promptTokens.withUnsafeBufferPointer { tokens in
            params.prompt_tokens = tokens.baseAddress
            params.prompt_n_tokens = Int32(tokens.count)
            return audioBuffer.withUnsafeBufferPointer { bufferPtr in
                whisper_full(context, params, bufferPtr.baseAddress, Int32(audioBuffer.count))
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        // A cancel aborts whisper_full with a non-zero result. Distinguish it from a
        // genuine failure so the engine can go idle silently instead of surfacing an error.
        if cancelFlag.isCancelled {
            fputs("[WhisperBridge] Cancelled in \(String(format: "%.2f", elapsed))s\n", stderr)
            throw WhisperError.cancelled
        }

        guard result == 0 else {
            fputs("[WhisperBridge] Failed (\(result)) in \(String(format: "%.2f", elapsed))s\n", stderr)
            throw WhisperError.transcriptionFailed(code: result)
        }

        // Collect full transcription (callback already typed segments incrementally)
        let segmentCount = whisper_full_n_segments(context)
        var transcription = ""
        for i in 0..<segmentCount {
            if let text = whisper_full_get_segment_text(context, i) {
                transcription += String(cString: text)
            }
        }

        let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        fputs("[WhisperBridge] Done (\(String(format: "%.2f", elapsed))s)\n", stderr)
        let languageID = whisper_full_lang_id(context)
        let detected = languageID >= 0 ? whisper_lang_str(languageID).map { String(cString: $0) } : nil
        return Transcription(text: trimmed, detectedLanguage: detected)
    }
}

enum WhisperError: LocalizedError {
    case incompatibleLanguage
    case modelLoadFailed(String)
    case transcriptionFailed(code: Int32)
    case cancelled

    /// User-intended cancellation — the engine should reset to idle without surfacing
    /// an error to the user.
    var isCancellation: Bool {
        if case .cancelled = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .incompatibleLanguage:
            return L10n.text("Dutch and automatic dictation require a multilingual model. Select one in Settings.")
        case .modelLoadFailed(let path):
            return L10n.text("Failed to load Whisper model at: %@", path)
        case .transcriptionFailed(let code):
            return L10n.text("Transcription failed (whisper error %d). Try again or switch models in Settings.", code)
        case .cancelled:
            return L10n.text("Transcription cancelled.")
        }
    }
}
