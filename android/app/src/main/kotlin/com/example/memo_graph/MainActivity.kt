package com.example.memo_graph

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Thread {
            File(filesDir, "qwen3-0.6b-int4.litertlm").delete()
            File(filesDir, "qwen3-0.6b-int4.tmp").delete()
        }.start()
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
                var done = false
                var bound = false
                lateinit var connection: ServiceConnection
                fun finish(text: String?, error: String?) {
                    if (done) return
                    done = true
                    if (bound) { unbindService(connection); bound = false }
                    if (error == null) result.success(text) else result.error("handwriting_failed", error, null)
                }
                val reply = Messenger(Handler(Looper.getMainLooper()) { message ->
                    finish(message.data.getString("text"), message.data.getString("error"))
                    true
                })
                connection = object : ServiceConnection {
                    override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                        try {
                            val message = Message.obtain(null, 1).apply {
                                replyTo = reply
                                data = Bundle().apply {
                                    putString("language", language)
                                    putString("strokes", JSONArray(strokes).toString())
                                    putDouble("aspectRatio", call.argument<Double>("aspectRatio") ?: (1024.0 / 1400.0))
                                }
                            }
                            Messenger(binder).send(message)
                        } catch (e: Exception) { finish(null, e.message ?: "Recognition unavailable") }
                    }
                    override fun onServiceDisconnected(name: ComponentName?) { finish(null, "Recognition service stopped") }
                    override fun onBindingDied(name: ComponentName?) { finish(null, "Recognition service stopped") }
                    override fun onNullBinding(name: ComponentName?) { finish(null, "Recognition service unavailable") }
                }
                try {
                    bound = bindService(Intent(this, HandwritingService::class.java), connection, Context.BIND_AUTO_CREATE)
                    if (!bound) finish(null, "Recognition service unavailable")
                } catch (e: Exception) { finish(null, e.message ?: "Recognition service unavailable") }
            }
    }
}
