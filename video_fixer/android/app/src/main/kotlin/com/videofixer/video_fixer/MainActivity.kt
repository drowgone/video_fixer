package com.videofixer.video_fixer

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.videofixer.video_fixer/share"
    private var sharedVideoPath: String? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getSharedVideo") {
                result.success(sharedVideoPath)
                sharedVideoPath = null // Reset after consumption
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
        // If app is already running, send the path to Flutter immediately
        sharedVideoPath?.let { path ->
            methodChannel?.invokeMethod("onSharedVideo", path)
            sharedVideoPath = null
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type

        if (Intent.ACTION_SEND == action && type != null) {
            if (type.startsWith("video/")) {
                val videoUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                if (videoUri != null) {
                    sharedVideoPath = copyUriToCache(videoUri)
                }
            }
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        try {
            val contentResolver = contentResolver
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            if (inputStream != null) {
                // Generate a unique name for the temp file
                val tempFile = File(cacheDir, "shared_video_${System.currentTimeMillis()}.mp4")
                val outputStream = FileOutputStream(tempFile)
                val buffer = ByteArray(1024 * 1024) // 1MB buffer
                var bytesRead: Int
                while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                    outputStream.write(buffer, 0, bytesRead)
                }
                outputStream.close()
                inputStream.close()
                return tempFile.absolutePath
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }
}
