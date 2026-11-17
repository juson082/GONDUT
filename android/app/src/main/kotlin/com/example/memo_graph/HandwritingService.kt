package com.example.memo_graph

import android.app.Service
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import org.json.JSONArray
import java.util.concurrent.Executors

/** Run native recognition separately so a native failure cannot kill the editor. */
class HandwritingService : Service() {
    private val worker = Executors.newSingleThreadExecutor()
    private val recognizer by lazy { HandwritingRecognizer(applicationContext) }
    private val messenger = Messenger(Handler(Looper.getMainLooper()) { request ->
        val reply = request.replyTo
        val data = request.data
        worker.execute {
            val response = Bundle()
            try {
                val raw = JSONArray(data.getString("strokes"))
                val strokes = (0 until raw.length()).map { i ->
                    val stroke = raw.getJSONArray(i)
                    (0 until stroke.length()).map { j ->
                        val point = stroke.getJSONArray(j)
                        listOf(point.getDouble(0), point.getDouble(1))
                    }
                }
                response.putString("text", recognizer.recognize(data.getString("language") ?: "", strokes, data.getDouble("aspectRatio")))
            } catch (e: Throwable) {
                response.putString("error", e.message ?: "Recognition failed")
            }
            try { reply.send(Message.obtain().apply { this.data = response }) } catch (_: Exception) { }
        }
        true
    })
    override fun onBind(intent: Intent?): IBinder = messenger.binder
    override fun onDestroy() {
        worker.execute { recognizer.close() }
        worker.shutdown()
        super.onDestroy()
    }
}
