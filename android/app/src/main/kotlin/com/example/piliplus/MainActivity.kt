package com.example.piliplus

import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.WindowManager.LayoutParams
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (AndroidHelper.isFoldable) {
            AndroidHelper.ToDart.onConfigurationChanged?.run()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        AndroidHelper.ToDart.onUserLeaveHint?.run()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration?) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        AndroidHelper.isPipMode = isInPictureInPictureMode
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.piliplus/export")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "muxVideoAudio" -> {
                        val videoPath = call.argument<String>("videoPath")
                        val audioPath = call.argument<String>("audioPath")
                        val outputPath = call.argument<String>("outputPath")
                        if (videoPath == null || audioPath == null || outputPath == null) {
                            result.error("INVALID_ARGS", "Paths cannot be null", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            val success = AndroidHelper.muxVideoAudio(videoPath, audioPath, outputPath)
                            runOnUiThread {
                                result.success(success)
                            }
                        }.start()
                    }
                    "getPublicDownloadDir" -> {
                        result.success(AndroidHelper.getPublicDownloadDir())
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
