package com.confidentcam.confident_cam

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.OutputStream
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * Native Android zero-beep, concurrent-capture Default ASR Manager.
 *
 * Captures 16 kHz mono PCM16 inside ConfidentCam's own foreground UID (same UID
 * as camera `MediaRecorder`, so Android keeps both audio streams unsilenced)
 * and pipes PCM via Android 13+ `EXTRA_AUDIO_SOURCE` + `EXTRA_SEGMENTED_SESSION`
 * into on-device `SodaSpeechRecognizer`, with:
 * - Zero system mic beep
 * - Android 14+ automatic spoken language detection & switching (EN / HI)
 * - Confidence scores + top alternative hypotheses for robust sentence matching
 * - Native partial-result throttling & deduplication to minimize CPU, battery,
 *   and IPC traffic.
 */
class NativeVoiceSyncManager(
    private val context: Context,
    messenger: BinaryMessenger,
    private val preferredDeviceProvider: () -> AudioDeviceInfo? = { null },
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.confidentcam.confident_cam/voice_sync"
        private const val TAG = "NativeVoiceSync"
        private const val SAMPLE_RATE = 16000
        private const val CHUNK_SAMPLES = 320 // 20 ms at 16 kHz (640 bytes)
        private const val PARTIAL_THROTTLE_MS = 240L
        private const val ACTIVE_LEVEL_EMIT_MS = 120L
        private const val IDLE_LEVEL_EMIT_MS = 400L
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val supportExecutor = Executors.newSingleThreadExecutor()

    private val isRunning = AtomicBoolean(false)
    private val isPaused = AtomicBoolean(false)
    private val pipeLock = Any()

    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var pipeWriteStream: OutputStream? = null
    private var pipeReadPfd: ParcelFileDescriptor? = null

    private var preferredLocales: List<String> = listOf("en-US", "en-IN", "hi-IN")
    private var resolvedLocale: String = "en-US"
    private var useOnDevice: Boolean = true
    private var recognizerRestartAttempts: Int = 0
    private var recognizerGeneration: Int = 0
    private var pendingRestartRunnable: Runnable? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val locales = call.argument<List<String>>("preferredLocales")
                    ?.filter { it.isNotBlank() }
                    ?: listOf("en-US", "en-IN", "hi-IN")
                val started = start(locales = locales)
                result.success(started)
            }
            "pause" -> {
                pause()
                result.success(true)
            }
            "resume" -> {
                resume()
                result.success(true)
            }
            "stop" -> {
                stop()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun start(locales: List<String>): Boolean {
        if (ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.RECORD_AUDIO,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            emitStatus("unavailableFallback", engine = "no_permission")
            return false
        }

        stop()

        preferredLocales = locales.map { it.replace('_', '-') }
        resolvedLocale = preferredLocales.firstOrNull() ?: "en-US"
        recognizerRestartAttempts = 0
        isPaused.set(false)
        useOnDevice = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)

        val record = createAudioRecord()
        if (record == null) {
            Log.w(TAG, "Failed to initialize in-process AudioRecord")
            emitStatus("unavailableFallback", engine = "audio_record_failed")
            return false
        }

        audioRecord = record
        isRunning.set(true)
        emitStatus("initializing", engine = "platform_default")

        startAudioCaptureThread(record)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            startPipedSpeechRecognizer()
        } else {
            emitStatus("unavailableFallback", engine = "api_below_33", locale = resolvedLocale)
            stop()
            return false
        }

        return true
    }

    private fun pause() {
        if (!isRunning.get()) return
        isPaused.set(true)
        emitStatus("paused", engine = "platform_default", locale = resolvedLocale)
    }

    private fun resume() {
        if (!isRunning.get()) return
        isPaused.set(false)
        emitStatus("listening", engine = "platform_default", locale = resolvedLocale)
    }

    fun stop() {
        isRunning.set(false)
        isPaused.set(false)
        recognizerGeneration++

        pendingRestartRunnable?.let { mainHandler.removeCallbacks(it) }
        pendingRestartRunnable = null

        closePipe()

        val record = audioRecord
        audioRecord = null
        try {
            record?.stop()
        } catch (_: Exception) {
        }
        try {
            record?.release()
        } catch (_: Exception) {
        }

        captureThread?.interrupt()
        captureThread = null

        mainHandler.post {
            destroySpeechRecognizer()
        }
        emitStatus("stopped", engine = "stopped")
    }

    fun dispose() {
        stop()
        channel.setMethodCallHandler(null)
        supportExecutor.shutdownNow()
    }

    private fun createAudioRecord(): AudioRecord? {
        val minBuf = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuf <= 0) return null
        val bufferSize = maxOf(minBuf * 4, CHUNK_SAMPLES * 2 * 16)

        val sources = intArrayOf(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            MediaRecorder.AudioSource.MIC,
        )
        for (source in sources) {
            try {
                val candidate = AudioRecord(
                    source,
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize,
                )
                if (candidate.state == AudioRecord.STATE_INITIALIZED) {
                    val preferredDevice = preferredDeviceProvider()
                    if (preferredDevice != null) {
                        try {
                            candidate.setPreferredDevice(preferredDevice)
                        } catch (e: Exception) {
                            Log.w(TAG, "setPreferredDevice warning: ${e.message}")
                        }
                    }
                    candidate.startRecording()
                    if (candidate.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                        Log.i(
                            TAG,
                            "AudioRecord started (source=$source, buf=$bufferSize)",
                        )
                        return candidate
                    }
                }
                candidate.release()
            } catch (e: Exception) {
                Log.w(TAG, "AudioRecord source=$source failed: ${e.message}")
            }
        }
        return null
    }

    private fun startAudioCaptureThread(record: AudioRecord) {
        val thread = Thread({
            android.os.Process.setThreadPriority(
                android.os.Process.THREAD_PRIORITY_URGENT_AUDIO,
            )
            val shortBuf = ShortArray(CHUNK_SAMPLES)
            val byteBuf = ByteArray(CHUNK_SAMPLES * 2)
            val silenceBytes = ByteArray(CHUNK_SAMPLES * 2)

            var lastLevelEmitMs = 0L
            var lastEmittedSpeaking = false
            var noiseFloorDb = -52.0
            var ambientCalibrationFrames = 0
            var consecutiveSpeechFrames = 0
            var consecutiveSilencedChecks = 0

            while (isRunning.get() && !Thread.currentThread().isInterrupted) {
                val samplesRead = try {
                    record.read(shortBuf, 0, shortBuf.size)
                } catch (e: Exception) {
                    Log.w(TAG, "AudioRecord read interrupted: ${e.message}")
                    break
                }
                if (samplesRead <= 0) continue

                val bytesRead = samplesRead * 2
                val paused = isPaused.get()

                var sumSq = 0.0
                if (!paused) {
                    for (i in 0 until samplesRead) {
                        val sample = shortBuf[i].toInt()
                        sumSq += sample.toDouble() * sample.toDouble()
                        val bIdx = i * 2
                        byteBuf[bIdx] = (sample and 0xFF).toByte()
                        byteBuf[bIdx + 1] = ((sample ushr 8) and 0xFF).toByte()
                    }
                }

                // Pipe live PCM (or silence while paused) straight into SpeechRecognizer
                synchronized(pipeLock) {
                    val out = pipeWriteStream
                    if (out != null) {
                        try {
                            out.write(
                                if (paused) silenceBytes else byteBuf,
                                0,
                                bytesRead,
                            )
                        } catch (_: IOException) {
                            try {
                                out.close()
                            } catch (_: Exception) {
                            }
                            pipeWriteStream = null
                        }
                    }
                }

                val rms = if (!paused) sqrt(sumSq / samplesRead) else 0.0
                val rmsDb = if (rms > 1.0) 20.0 * log10(rms / 32768.0) else -60.0
                if (!paused) {
                    if (ambientCalibrationFrames < 5) {
                        noiseFloorDb = if (ambientCalibrationFrames == 0) {
                            rmsDb.coerceIn(-58.0, -28.0)
                        } else {
                            (noiseFloorDb * 0.6 + rmsDb * 0.4).coerceIn(-58.0, -28.0)
                        }
                        ambientCalibrationFrames++
                    } else if (rmsDb < noiseFloorDb) {
                        noiseFloorDb = noiseFloorDb * 0.85 + rmsDb * 0.15
                    } else if (rmsDb < noiseFloorDb + 12.0) {
                        noiseFloorDb = (noiseFloorDb * 0.985 + rmsDb * 0.015).coerceAtMost(-28.0)
                    }
                }
                val thresholdDb = maxOf(-38.0, noiseFloorDb + 9.0)
                if (!paused && ambientCalibrationFrames >= 5 && rmsDb > thresholdDb) {
                    consecutiveSpeechFrames++
                } else {
                    consecutiveSpeechFrames = 0
                }
                val isSpeaking = !paused && consecutiveSpeechFrames >= 2
                val nowMs = System.currentTimeMillis()

                // Emit voice level sparsely to save battery & IPC overhead
                val emitInterval = if (isSpeaking) ACTIVE_LEVEL_EMIT_MS else IDLE_LEVEL_EMIT_MS
                val stateChanged = isSpeaking != lastEmittedSpeaking
                if (stateChanged || (nowMs - lastLevelEmitMs >= emitInterval)) {
                    lastLevelEmitMs = nowMs
                    lastEmittedSpeaking = isSpeaking

                    val clientSilenced = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        record.activeRecordingConfiguration?.isClientSilenced == true
                    } else {
                        false
                    }

                    if (clientSilenced && !paused) {
                        consecutiveSilencedChecks++
                    } else {
                        consecutiveSilencedChecks = 0
                    }

                    emitVoiceLevel(
                        rmsDb = rmsDb,
                        isSpeaking = isSpeaking,
                        silenced = consecutiveSilencedChecks >= 8,
                    )
                }
            }
        }, "ConfidentCamVoiceCapture")
        captureThread = thread
        thread.start()
    }

    private fun startPipedSpeechRecognizer() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val gen = ++recognizerGeneration

        mainHandler.post {
            if (!isRunning.get() || gen != recognizerGeneration) return@post

            destroySpeechRecognizer()

            val recognizer = try {
                if (useOnDevice && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
                    SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
                } else {
                    SpeechRecognizer.createSpeechRecognizer(context)
                }
            } catch (e: Exception) {
                Log.w(TAG, "createSpeechRecognizer failed: ${e.message}")
                null
            }

            if (recognizer == null) {
                emitStatus("unavailableFallback", engine = "recognizer_null", locale = resolvedLocale)
                return@post
            }

            speechRecognizer = recognizer

            if (useOnDevice) {
                val checkIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                try {
                    recognizer.checkRecognitionSupport(
                        checkIntent,
                        supportExecutor,
                        object : RecognitionSupportCallback {
                            override fun onSupportResult(support: RecognitionSupport) {
                                val installed = support.installedOnDeviceLanguages
                                val supported = support.supportedOnDeviceLanguages
                                val chosen = pickBestLocale(installed, supported)
                                val allowedForSwitch = ArrayList(
                                    installed.filter { lang ->
                                        val norm = lang.lowercase()
                                        norm.startsWith("en") || norm.startsWith("hi")
                                    }.ifEmpty { listOf(chosen) },
                                )
                                mainHandler.post {
                                    if (!isRunning.get() || gen != recognizerGeneration) return@post
                                    resolvedLocale = chosen
                                    Log.i(
                                        TAG,
                                        "On-device installed=$installed -> primary=$resolvedLocale, switch=$allowedForSwitch",
                                    )
                                    launchPipedSession(recognizer, resolvedLocale, allowedForSwitch, gen)
                                }
                            }

                            override fun onError(error: Int) {
                                mainHandler.post {
                                    if (!isRunning.get() || gen != recognizerGeneration) return@post
                                    launchPipedSession(
                                        recognizer,
                                        resolvedLocale,
                                        ArrayList(preferredLocales),
                                        gen,
                                    )
                                }
                            }
                        },
                    )
                } catch (_: Exception) {
                    launchPipedSession(
                        recognizer,
                        resolvedLocale,
                        ArrayList(preferredLocales),
                        gen,
                    )
                }
            } else {
                launchPipedSession(
                    recognizer,
                    resolvedLocale,
                    ArrayList(preferredLocales),
                    gen,
                )
            }
        }
    }

    private fun pickBestLocale(
        installed: List<String>,
        supported: List<String>,
    ): String {
        val normalizedInstalled = installed.associateBy { it.replace('_', '-').lowercase() }
        for (pref in preferredLocales) {
            val exact = normalizedInstalled[pref.lowercase()]
            if (exact != null) return exact
        }
        for (pref in preferredLocales) {
            val langPrefix = pref.substringBefore('-').lowercase()
            val match = installed.firstOrNull {
                it.replace('_', '-').lowercase().startsWith("$langPrefix-")
            }
            if (match != null) return match
        }
        if (installed.isNotEmpty()) return installed.first()

        val normalizedSupported = supported.associateBy { it.replace('_', '-').lowercase() }
        for (pref in preferredLocales) {
            val exact = normalizedSupported[pref.lowercase()]
            if (exact != null) return exact
        }
        return preferredLocales.firstOrNull() ?: "en-US"
    }

    private fun launchPipedSession(
        recognizer: SpeechRecognizer,
        localeTag: String,
        allowedLanguages: ArrayList<String>,
        generation: Int,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (!isRunning.get() || generation != recognizerGeneration) return

        closePipe()
        val pipe = try {
            ParcelFileDescriptor.createPipe()
        } catch (_: IOException) {
            emitStatus("unavailableFallback", engine = "pipe_failed", locale = localeTag)
            return
        }

        val readPfd = pipe[0]
        val writePfd = pipe[1]
        synchronized(pipeLock) {
            pipeReadPfd = readPfd
            pipeWriteStream = ParcelFileDescriptor.AutoCloseOutputStream(writePfd)
        }

        recognizer.setRecognitionListener(object : RecognitionListener {
            private var lastEmittedLanguage: String? = null
            private var lastLanguageEmitMs: Long = 0L
            private var lastPartialText: String = ""
            private var lastPartialEmitMs: Long = 0L

            override fun onReadyForSpeech(params: Bundle?) {
                if (!isRunning.get() || generation != recognizerGeneration) return
                recognizerRestartAttempts = 0
                emitStatus(
                    if (isPaused.get()) "paused" else "listening",
                    engine = if (useOnDevice) "on_device_pipe" else "network_pipe",
                    locale = localeTag,
                )
            }

            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}

            override fun onLanguageDetection(results: Bundle) {
                if (!isRunning.get() || generation != recognizerGeneration) return
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    val detected = results.getString(SpeechRecognizer.DETECTED_LANGUAGE)
                    val confidence = results.getInt(
                        SpeechRecognizer.LANGUAGE_DETECTION_CONFIDENCE_LEVEL,
                        SpeechRecognizer.LANGUAGE_DETECTION_CONFIDENCE_LEVEL_CONFIDENT,
                    )
                    val now = System.currentTimeMillis()
                    if (!detected.isNullOrBlank() &&
                        confidence >= SpeechRecognizer.LANGUAGE_DETECTION_CONFIDENCE_LEVEL_CONFIDENT &&
                        (detected != lastEmittedLanguage || now - lastLanguageEmitMs >= 1200L)
                    ) {
                        lastEmittedLanguage = detected
                        lastLanguageEmitMs = now
                        emitLanguageDetected(detected)
                    }
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                if (!isRunning.get() || isPaused.get() || generation != recognizerGeneration) return
                val payload = extractRecognitionPayload(partialResults) ?: return
                val now = System.currentTimeMillis()
                // Deduplicate and throttle partial results at native layer to eliminate
                // rapid partial flicker and excess MethodChannel traffic.
                if (payload.primary == lastPartialText) return
                if (now - lastPartialEmitMs < PARTIAL_THROTTLE_MS) return
                lastPartialText = payload.primary
                lastPartialEmitMs = now
                emitWords(
                    text = payload.primary,
                    alternatives = payload.alternatives,
                    confidence = payload.confidence,
                    isFinal = false,
                )
            }

            override fun onSegmentResults(segmentResults: Bundle) {
                if (!isRunning.get() || isPaused.get() || generation != recognizerGeneration) return
                val payload = extractRecognitionPayload(segmentResults) ?: return
                lastPartialText = ""
                emitWords(
                    text = payload.primary,
                    alternatives = payload.alternatives,
                    confidence = payload.confidence,
                    isFinal = true,
                )
            }

            override fun onResults(results: Bundle?) {
                if (!isRunning.get() || isPaused.get() || generation != recognizerGeneration) return
                val payload = extractRecognitionPayload(results)
                lastPartialText = ""
                if (payload != null) {
                    emitWords(
                        text = payload.primary,
                        alternatives = payload.alternatives,
                        confidence = payload.confidence,
                        isFinal = true,
                    )
                }
                scheduleRecognizerRestart(delayMs = 120L)
            }

            override fun onEndOfSegmentedSession() {
                if (!isRunning.get() || generation != recognizerGeneration) return
                lastPartialText = ""
                scheduleRecognizerRestart(delayMs = 120L)
            }

            override fun onError(error: Int) {
                if (!isRunning.get() || generation != recognizerGeneration) return
                Log.w(TAG, "SpeechRecognizer error=$error (onDevice=$useOnDevice, locale=$localeTag)")

                if (error == SpeechRecognizer.ERROR_NO_MATCH ||
                    error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT
                ) {
                    scheduleRecognizerRestart(delayMs = 180L)
                    return
                }

                if (useOnDevice &&
                    (error == SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ||
                        error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ||
                        error == SpeechRecognizer.ERROR_AUDIO ||
                        error == SpeechRecognizer.ERROR_CLIENT)
                ) {
                    useOnDevice = false
                    recognizerRestartAttempts = 0
                    scheduleRecognizerRestart(delayMs = 240L)
                    return
                }

                recognizerRestartAttempts++
                if (recognizerRestartAttempts <= 4) {
                    scheduleRecognizerRestart(delayMs = 400L)
                } else {
                    closePipe()
                    destroySpeechRecognizer()
                    emitStatus("unavailableFallback", engine = "asr_error_$error", locale = localeTag)
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeTag)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, readPfd)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
            putExtra(
                RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, SAMPLE_RATE)
            putExtra(
                RecognizerIntent.EXTRA_SEGMENTED_SESSION,
                RecognizerIntent.EXTRA_AUDIO_SOURCE,
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                putExtra(RecognizerIntent.EXTRA_ENABLE_LANGUAGE_DETECTION, true)
                if (allowedLanguages.size > 1) {
                    putStringArrayListExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_DETECTION_ALLOWED_LANGUAGES,
                        allowedLanguages,
                    )
                    putExtra(
                        RecognizerIntent.EXTRA_ENABLE_LANGUAGE_SWITCH,
                        RecognizerIntent.LANGUAGE_SWITCH_BALANCED,
                    )
                }
            }
            if (useOnDevice) {
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            }
        }

        try {
            recognizer.startListening(intent)
            Log.i(
                TAG,
                "Started silent piped SpeechRecognizer (onDevice=$useOnDevice, locale=$localeTag, autoLang=${Build.VERSION.SDK_INT >= 34})",
            )
        } catch (e: Exception) {
            Log.w(TAG, "startListening failed: ${e.message}")
            closePipe()
            emitStatus("unavailableFallback", engine = "start_failed", locale = localeTag)
        }
    }

    private fun scheduleRecognizerRestart(delayMs: Long) {
        if (!isRunning.get()) return
        pendingRestartRunnable?.let { mainHandler.removeCallbacks(it) }
        val runnable = Runnable {
            if (isRunning.get()) {
                startPipedSpeechRecognizer()
            }
        }
        pendingRestartRunnable = runnable
        mainHandler.postDelayed(runnable, delayMs)
    }

    private data class RecognitionPayload(
        val primary: String,
        val alternatives: List<String>,
        val confidence: Double?,
    )

    private fun extractRecognitionPayload(bundle: Bundle?): RecognitionPayload? {
        val list = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            ?: return null
        if (list.isEmpty()) return null

        val scores = bundle.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
        val rawConf = scores?.firstOrNull()?.toDouble()
        val validConf = if (rawConf != null && rawConf >= 0.0 && rawConf <= 1.0) rawConf else null

        return RecognitionPayload(
            primary = list.first(),
            alternatives = list.drop(1).take(2),
            confidence = validConf,
        )
    }

    private fun closePipe() {
        synchronized(pipeLock) {
            try {
                pipeWriteStream?.close()
            } catch (_: Exception) {
            }
            pipeWriteStream = null
            try {
                pipeReadPfd?.close()
            } catch (_: Exception) {
            }
            pipeReadPfd = null
        }
    }

    private fun destroySpeechRecognizer() {
        val rec = speechRecognizer
        speechRecognizer = null
        if (rec != null) {
            try {
                rec.cancel()
            } catch (_: Exception) {
            }
            try {
                rec.destroy()
            } catch (_: Exception) {
            }
        }
    }

    private fun emitWords(
        text: String,
        alternatives: List<String>,
        confidence: Double?,
        isFinal: Boolean,
    ) {
        mainHandler.post {
            channel.invokeMethod(
                "onWords",
                mapOf(
                    "text" to text,
                    "alternatives" to alternatives,
                    "confidence" to confidence,
                    "isFinal" to isFinal,
                ),
            )
        }
    }

    private fun emitLanguageDetected(languageTag: String) {
        mainHandler.post {
            channel.invokeMethod(
                "onLanguageDetected",
                mapOf("language" to languageTag),
            )
        }
    }

    private fun emitVoiceLevel(rmsDb: Double, isSpeaking: Boolean, silenced: Boolean) {
        mainHandler.post {
            channel.invokeMethod(
                "onVoiceLevel",
                mapOf(
                    "rmsDb" to rmsDb,
                    "isSpeaking" to isSpeaking,
                    "silenced" to silenced,
                ),
            )
        }
    }

    private fun emitStatus(status: String, engine: String, locale: String? = null) {
        mainHandler.post {
            channel.invokeMethod(
                "onStatus",
                mapOf(
                    "status" to status,
                    "engine" to engine,
                    "locale" to locale,
                ),
            )
        }
    }
}
