package com.confidentcam.confident_cam

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native Android manager for:
 * 1. Enumerating all available audio input microphones (built-in, wired headset,
 *    USB-C / external, Bluetooth SCO / BLE) and listening for hot-plug events.
 * 2. Selecting a preferred microphone input device prior to recording (also
 *    shared with [NativeVoiceSyncManager] so ASR uses the same mic).
 * 3. Filtering notification sounds and system alerts during active recording via:
 *    - Exclusive transient audio focus (`AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE`)
 *    - Saving & muting notification/ring/system/DTMF/media streams
 *    - Optional Do-Not-Disturb (`INTERRUPTION_FILTER_NONE`) when policy access
 *      is granted, always cleanly restored on stop/dispose.
 */
class RecordingAudioManager(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.confidentcam.confident_cam/recording_audio"
        private const val TAG = "RecordingAudioMgr"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val notificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    @Volatile
    private var preferredInputDeviceId: Int? = null

    private var guardActive = false
    private var audioFocusRequest: AudioFocusRequest? = null
    private val previousStreamMuteStates = mutableMapOf<Int, Boolean>()
    private var previousInterruptionFilter: Int? = null
    private var bluetoothScoStarted = false

    private val streamsToMute = intArrayOf(
        AudioManager.STREAM_NOTIFICATION,
        AudioManager.STREAM_RING,
        AudioManager.STREAM_SYSTEM,
        AudioManager.STREAM_DTMF,
        AudioManager.STREAM_MUSIC,
    )

    private val deviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
            if (addedDevices?.any { it.isSource } == true) {
                emitDevicesChanged()
            }
        }

        override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
            if (removedDevices?.any { it.isSource } == true) {
                val prefId = preferredInputDeviceId
                if (prefId != null && removedDevices.any { it.id == prefId }) {
                    preferredInputDeviceId = null
                    clearExternalMicRouting()
                }
                emitDevicesChanged()
            }
        }
    }

    init {
        channel.setMethodCallHandler(this)
        audioManager.registerAudioDeviceCallback(deviceCallback, mainHandler)
    }

    /** Returns the user-selected [AudioDeviceInfo] if still connected, else null. */
    fun getPreferredInputDevice(): AudioDeviceInfo? {
        val targetId = preferredInputDeviceId ?: return null
        return audioManager
            .getDevices(AudioManager.GET_DEVICES_INPUTS)
            .firstOrNull { it.id == targetId }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listInputDevices" -> {
                result.success(buildInputDevicePayload())
            }
            "setPreferredInputDevice" -> {
                val deviceId = call.argument<Int>("deviceId")
                val ok = setPreferredInputDevice(deviceId)
                result.success(ok)
            }
            "beginRecordingAudioGuard" -> {
                val silenceNotifications = call.argument<Boolean>("silenceNotifications") ?: true
                beginRecordingAudioGuard(silenceNotifications)
                result.success(true)
            }
            "endRecordingAudioGuard" -> {
                endRecordingAudioGuard()
                result.success(true)
            }
            "hasDndPolicyAccess" -> {
                result.success(notificationManager.isNotificationPolicyAccessGranted)
            }
            "openDndPolicySettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    Log.w(TAG, "Unable to open DND policy settings: ${e.message}")
                    result.success(false)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun isSelectableInputType(type: Int): Boolean {
        if (type == AudioDeviceInfo.TYPE_BUILTIN_MIC ||
            type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
            type == AudioDeviceInfo.TYPE_USB_DEVICE ||
            type == AudioDeviceInfo.TYPE_USB_HEADSET ||
            type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
            type == AudioDeviceInfo.TYPE_LINE_ANALOG ||
            type == AudioDeviceInfo.TYPE_AUX_LINE
        ) {
            return true
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            type == AudioDeviceInfo.TYPE_BLE_HEADSET
        ) {
            return true
        }
        return false
    }

    private fun isExternalInputType(type: Int): Boolean =
        type != AudioDeviceInfo.TYPE_BUILTIN_MIC

    private fun friendlyTypeLabel(type: Int): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            type == AudioDeviceInfo.TYPE_BLE_HEADSET
        ) {
            return "Bluetooth LE"
        }
        return when (type) {
            AudioDeviceInfo.TYPE_BUILTIN_MIC -> "Built-in"
            AudioDeviceInfo.TYPE_WIRED_HEADSET -> "Wired Headset"
            AudioDeviceInfo.TYPE_USB_DEVICE, AudioDeviceInfo.TYPE_USB_HEADSET -> "USB Mic"
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth"
            AudioDeviceInfo.TYPE_LINE_ANALOG, AudioDeviceInfo.TYPE_AUX_LINE -> "Line In"
            else -> "Microphone"
        }
    }

    private fun buildInputDevicePayload(): List<Map<String, Any?>> {
        val rawDevices = audioManager
            .getDevices(AudioManager.GET_DEVICES_INPUTS)
            .filter { isSelectableInputType(it.type) }

        // Disambiguate multiple built-in mics (e.g., bottom vs top/back) cleanly
        val builtInCount = rawDevices.count { it.type == AudioDeviceInfo.TYPE_BUILTIN_MIC }
        var builtInOrdinal = 0

        val result = mutableListOf<Map<String, Any?>>()
        val seenKeys = mutableSetOf<String>()

        for (device in rawDevices) {
            val typeLabel = friendlyTypeLabel(device.type)
            val product = device.productName?.toString()?.trim().orEmpty()
            val address = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                device.address?.trim().orEmpty()
            } else {
                ""
            }

            val displayName = when (device.type) {
                AudioDeviceInfo.TYPE_BUILTIN_MIC -> {
                    builtInOrdinal++
                    when {
                        address.equals("bottom", ignoreCase = true) -> "Phone Mic (Bottom)"
                        address.equals("top", ignoreCase = true) -> "Phone Mic (Top)"
                        address.equals("back", ignoreCase = true) -> "Phone Mic (Back)"
                        builtInCount > 1 -> "Phone Mic $builtInOrdinal"
                        else -> "Phone Microphone"
                    }
                }
                else -> {
                    if (product.isNotEmpty() && !product.equals(Build.MODEL, ignoreCase = true)) {
                        "$product ($typeLabel)"
                    } else {
                        "$typeLabel Microphone"
                    }
                }
            }

            // Avoid duplicate virtual entries sharing identical name + type
            val dedupeKey = "${device.type}:$displayName"
            if (!seenKeys.add(dedupeKey)) continue

            result.add(
                mapOf(
                    "id" to device.id,
                    "name" to displayName,
                    "type" to device.type,
                    "typeLabel" to typeLabel,
                    "isExternal" to isExternalInputType(device.type),
                    "isSelected" to (preferredInputDeviceId == device.id),
                )
            )
        }

        // Put external mics first so connected USB/Bluetooth/Wired mics are easy to spot
        return result.sortedWith(
            compareByDescending<Map<String, Any?>> { it["isExternal"] as Boolean }
                .thenBy { it["id"] as Int }
        )
    }

    private fun setPreferredInputDevice(deviceId: Int?): Boolean {
        preferredInputDeviceId = deviceId
        if (deviceId == null) {
            clearExternalMicRouting()
            Log.i(TAG, "Microphone preference reset to System Auto")
            return true
        }

        val target = getPreferredInputDevice()
        if (target == null) {
            preferredInputDeviceId = null
            clearExternalMicRouting()
            return false
        }

        applyExternalMicRouting(target)
        Log.i(TAG, "Preferred microphone selected: id=${target.id}, type=${target.type}, name=${target.productName}")
        return true
    }

    private fun applyExternalMicRouting(target: AudioDeviceInfo) {
        val isBt = target.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                target.type == AudioDeviceInfo.TYPE_BLE_HEADSET)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                if (isExternalInputType(target.type)) {
                    val commMatch = audioManager.availableCommunicationDevices.firstOrNull {
                        it.id == target.id || it.type == target.type
                    }
                    if (commMatch != null) {
                        audioManager.setCommunicationDevice(commMatch)
                        Log.i(TAG, "Applied communication device routing: ${commMatch.productName}")
                    }
                } else {
                    audioManager.clearCommunicationDevice()
                }
            } catch (e: Exception) {
                Log.w(TAG, "setCommunicationDevice warning: ${e.message}")
            }
        } else if (isBt) {
            try {
                @Suppress("DEPRECATION")
                audioManager.startBluetoothSco()
                @Suppress("DEPRECATION")
                audioManager.isBluetoothScoOn = true
                bluetoothScoStarted = true
            } catch (e: Exception) {
                Log.w(TAG, "startBluetoothSco warning: ${e.message}")
            }
        } else {
            clearExternalMicRouting()
        }
    }

    private fun clearExternalMicRouting() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                audioManager.clearCommunicationDevice()
            } catch (_: Exception) {
            }
        }
        if (bluetoothScoStarted) {
            try {
                @Suppress("DEPRECATION")
                audioManager.isBluetoothScoOn = false
                @Suppress("DEPRECATION")
                audioManager.stopBluetoothSco()
            } catch (_: Exception) {
            }
            bluetoothScoStarted = false
        }
    }

    /**
     * Suppresses notification pings, ringtones, system clicks, and background
     * media audio so alerts never bleed into the recorded video.
     */
    fun beginRecordingAudioGuard(silenceNotifications: Boolean) {
        // Re-apply preferred external mic routing right before MediaRecorder opens
        getPreferredInputDevice()?.let { applyExternalMicRouting(it) }

        if (!silenceNotifications || guardActive) return
        guardActive = true

        // 1. Request exclusive transient audio focus so media/alert apps pause
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val attrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
                val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    .setAudioAttributes(attrs)
                    .setAcceptsDelayedFocusGain(false)
                    .setWillPauseWhenDucked(true)
                    .build()
                audioFocusRequest = req
                audioManager.requestAudioFocus(req)
            } else {
                @Suppress("DEPRECATION")
                audioManager.requestAudioFocus(
                    null,
                    AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE,
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "Audio focus request warning: ${e.message}")
        }

        // 2. Save & mute notification / ring / system / DTMF / music streams
        previousStreamMuteStates.clear()
        for (stream in streamsToMute) {
            try {
                val wasMuted = audioManager.isStreamMute(stream)
                previousStreamMuteStates[stream] = wasMuted
                if (!wasMuted) {
                    audioManager.adjustStreamVolume(
                        stream,
                        AudioManager.ADJUST_MUTE,
                        AudioManager.FLAG_REMOVE_SOUND_AND_VIBRATE,
                    )
                }
            } catch (e: Exception) {
                Log.w(TAG, "Mute stream $stream warning: ${e.message}")
            }
        }

        // 3. Optional Do-Not-Disturb silence when user granted Notification Policy access
        try {
            if (notificationManager.isNotificationPolicyAccessGranted) {
                previousInterruptionFilter = notificationManager.currentInterruptionFilter
                notificationManager.setInterruptionFilter(
                    NotificationManager.INTERRUPTION_FILTER_NONE,
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "DND interruption filter warning: ${e.message}")
        }

        Log.i(TAG, "Recording audio guard active (streams muted + audio focus acquired)")
    }

    /** Restores exact previous audio streams, DND filter, and audio focus. */
    fun endRecordingAudioGuard() {
        if (!guardActive) return
        guardActive = false

        // 1. Restore DND interruption filter if changed
        val prevFilter = previousInterruptionFilter
        previousInterruptionFilter = null
        if (prevFilter != null) {
            try {
                if (notificationManager.isNotificationPolicyAccessGranted) {
                    notificationManager.setInterruptionFilter(prevFilter)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Restore DND filter warning: ${e.message}")
            }
        }

        // 2. Restore exact previous mute state of every muted stream
        for ((stream, wasMuted) in previousStreamMuteStates) {
            if (!wasMuted) {
                try {
                    audioManager.adjustStreamVolume(
                        stream,
                        AudioManager.ADJUST_UNMUTE,
                        0,
                    )
                } catch (e: Exception) {
                    Log.w(TAG, "Unmute stream $stream warning: ${e.message}")
                }
            }
        }
        previousStreamMuteStates.clear()

        // 3. Abandon audio focus
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
                audioFocusRequest = null
            } else {
                @Suppress("DEPRECATION")
                audioManager.abandonAudioFocus(null)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Abandon audio focus warning: ${e.message}")
        }

        Log.i(TAG, "Recording audio guard ended (streams & audio focus restored)")
    }

    private fun emitDevicesChanged() {
        val payload = buildInputDevicePayload()
        mainHandler.post {
            try {
                channel.invokeMethod("onInputDevicesChanged", payload)
            } catch (_: Exception) {
            }
        }
    }

    fun dispose() {
        endRecordingAudioGuard()
        clearExternalMicRouting()
        try {
            audioManager.unregisterAudioDeviceCallback(deviceCallback)
        } catch (_: Exception) {
        }
        channel.setMethodCallHandler(null)
    }
}
