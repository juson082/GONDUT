package com.example.memo_graph

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "memo_graph/handwriting")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val language = call.argument<String>("language")
                val strokes = call.argument<List<List<List<Double>>>>("strokes")
                if (language == null || strokes == null) {
                    result.error("invalid_input", "Missing handwriting or language", null)
                    return@setMethodCallHandler
                }
                worker.execute {
                    try {
                        val text = HandwritingRecognizer(applicationContext).recognize(language, strokes)
                        runOnUiThread { result.success(text) }
                    } catch (e: Throwable) {
                        runOnUiThread { result.error("handwriting_failed", e.message ?: "Recognition failed", null) }
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "memo_graph/local_ai")
            .setMethodCallHandler { call, result ->
                if (call.method != "extract") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val prompt = call.argument<String>("prompt")
                if (prompt.isNullOrBlank() || prompt.length > 12000) {
                    result.error("invalid_input", "Invalid extraction input", null)
                    return@setMethodCallHandler
                }
                worker.execute {
                    try {
                        val model = File(filesDir, "qwen3-0.6b-int4.litertlm")
                        if (!model.exists() || model.length() != 347251840L) {
                            val temporary = File(filesDir, "qwen3-0.6b-int4.tmp")
                            assets.open("flutter_assets/assets/llm/qwen3-0.6b-int4.litertlm").use { input ->
                                temporary.outputStream().use { output -> input.copyTo(output) }
                            }
                            check(temporary.length() == 347251840L) { "Incomplete model copy" }
                            if (model.exists()) check(model.delete()) { "Could not replace incomplete model" }
                            check(temporary.renameTo(model)) { "Could not install model" }
                        }
                        val output = Engine(EngineConfig(modelPath = model.absolutePath, backend = Backend.CPU())).use { engine ->
                            engine.initialize()
                            engine.createConversation().use { conversation ->
                                conversation.sendMessage(prompt).toString()
                            }
                        }
                        runOnUiThread { result.success(output) }
                    } catch (e: Throwable) {
                        runOnUiThread { result.error("local_ai_failed", e.message ?: "Local AI failed", null) }
                    }
                }
            }
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }
}
