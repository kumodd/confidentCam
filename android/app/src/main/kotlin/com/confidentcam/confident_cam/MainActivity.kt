package com.confidentcam.confident_cam

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var recordingAudioManager: RecordingAudioManager? = null
    private var voiceSyncManager: NativeVoiceSyncManager? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
    }

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
