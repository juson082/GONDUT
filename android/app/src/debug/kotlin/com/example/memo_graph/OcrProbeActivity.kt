package com.example.memo_graph

import android.app.Activity
import android.os.Bundle
import android.util.Log

/** Debug-only synthetic strokes: never reads a user's writing. */
class OcrProbeActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Thread {
            val recognizer = HandwritingRecognizer(applicationContext)
            try {
                val ink = listOf(
                    listOf(listOf(.15, .2), listOf(.30, .2), listOf(.30, .32)),
                    listOf(listOf(.15, .32), listOf(.30, .32)),
                    listOf(listOf(.36, .18), listOf(.36, .35)),
                    listOf(listOf(.36, .26), listOf(.42, .26))
                )
                val text = recognizer.recognize("ko", ink, 1.0)
                Log.i("GondutOcrProbe", "result=$text")
            } catch (e: Throwable) {
                Log.e("GondutOcrProbe", "recognition failed", e)
            } finally {
                recognizer.close()
                runOnUiThread { finish() }
            }
        }.start()
    }
}
