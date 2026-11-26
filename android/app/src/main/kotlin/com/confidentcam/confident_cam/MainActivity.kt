package com.confidentcam.confident_cam

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var recordingAudioManager: RecordingAudioManager? = null
    private var voiceSyncManager: NativeVoiceSyncManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val audioMgr = RecordingAudioManager(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
        recordingAudioManager = audioMgr
        voiceSyncManager = NativeVoiceSyncManager(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
            preferredDeviceProvider = { audioMgr.getPreferredInputDevice() },
        )
    }

    override fun onDestroy() {
        voiceSyncManager?.dispose()
        voiceSyncManager = null
        recordingAudioManager?.dispose()
        recordingAudioManager = null
        super.onDestroy()
    }
}
