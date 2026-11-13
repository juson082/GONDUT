package com.example.memo_graph

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.io.File

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val handwritingRecognizer by lazy { HandwritingRecognizer(applicationContext) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Remove only the obsolete graph model cache, never user-created data.
        worker.execute {
            File(filesDir, "qwen3-0.6b-int4.litertlm").delete()
            File(filesDir, "qwen3-0.6b-int4.tmp").delete()
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "memo_graph/handwriting")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val language = call.argument<String>("language")
                val strokes = call.argument<List<List<List<Double>>>>("strokes")
                val aspectRatio = call.argument<Double>("aspectRatio") ?: (1024.0 / 1400.0)
                if (language == null || strokes == null) {
                    result.error("invalid_input", "Missing handwriting or language", null)
                    return@setMethodCallHandler
                }
                worker.execute {
                    try {
                        val text = handwritingRecognizer.recognize(language, strokes, aspectRatio)
                        runOnUiThread { result.success(text) }
                    } catch (e: Throwable) {
                        runOnUiThread { result.error("handwriting_failed", e.message ?: "Recognition failed", null) }
                    }
                }
            }
    }

    override fun onDestroy() {
        worker.execute { handwritingRecognizer.close() }
        worker.shutdown()
        super.onDestroy()
    }
}
