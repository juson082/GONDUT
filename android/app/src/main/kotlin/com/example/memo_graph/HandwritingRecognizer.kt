package com.example.memo_graph

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import java.io.File
import java.nio.FloatBuffer
import java.text.Normalizer
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/** Local line recognition. No image, strokes, or text leave the device. */
class HandwritingRecognizer(private val context: Context) {
    private val env = OrtEnvironment.getEnvironment()
    private val width = 1024
    private var height = 1400
    private val sessions = mutableMapOf<String, OrtSession>()
    private val dictionaries = mutableMapOf<String, List<String>>()

    fun close() { sessions.values.forEach { it.close() }; sessions.clear() }

    fun recognize(language: String, raw: List<List<List<Double>>>, aspectRatio: Double): String {
        require(aspectRatio.isFinite() && aspectRatio > 0.0)
        height = (width / aspectRatio).toInt().coerceIn(256, 4096)
        val modelName = when (language) {
            "ko" -> "korean"
            "ja", "zh" -> "chinese"
            "en", "es", "fr", "de", "it", "pt", "nl", "pl", "cs", "sk",
            "hr", "bs", "sl", "da", "no", "sv", "is", "et", "lt", "hu",
            "sq", "cy", "ga", "tr", "id", "ms", "af", "sw", "tl", "uz", "la" -> "latin"
            else -> throw IllegalArgumentException("Unsupported handwriting language")
        }
        require(raw.isNotEmpty() && raw.size <= 10000)
        require(raw.sumOf { it.size } <= 100000)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        try {
            val canvas = Canvas(bitmap)
            canvas.drawColor(Color.WHITE)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.BLACK; strokeWidth = 7f; strokeCap = Paint.Cap.ROUND
                strokeJoin = Paint.Join.ROUND; style = Paint.Style.STROKE
            }
            for (stroke in raw) {
                if (stroke.isEmpty()) continue
                require(stroke.all { it.size == 2 && it[0].isFinite() && it[1].isFinite() && it[0] in 0.0..1.0 && it[1] in 0.0..1.0 })
                val path = Path()
                path.moveTo((stroke[0][0] * width).toFloat(), (stroke[0][1] * height).toFloat())
                for (point in stroke.drop(1)) path.lineTo((point[0] * width).toFloat(), (point[1] * height).toFloat())
                if (stroke.size == 1) canvas.drawPoint((stroke[0][0] * width).toFloat(), (stroke[0][1] * height).toFloat(), paint)
                else canvas.drawPath(path, paint)
            }
            val lines = lineBounds(bitmap)
            if (lines.isEmpty()) return ""
            val model = installAsset(modelName, "rec.onnx")
            val dictionary = dictionaries.getOrPut(modelName) {
                context.assets.open("flutter_assets/assets/handwriting/$modelName/dict.txt")
                    .bufferedReader(Charsets.UTF_8).use { it.readLines() }
            }
            val session = sessions.getOrPut(modelName) {
                OrtSession.SessionOptions().use { options ->
                    options.setIntraOpNumThreads(2)
                    env.createSession(model.absolutePath, options)
                }
            }
            return lines.joinToString("\n") { line -> recognizeLine(bitmap, line, session, dictionary) }.trim()
        } finally { bitmap.recycle() }
    }

    private fun installAsset(group: String, filename: String): File {
        val target = File(context.filesDir, "handwriting_${group}_$filename")
        val asset = "flutter_assets/assets/handwriting/$group/$filename"
        val expected = when (group) { "korean" -> 14790116L; "chinese" -> 84468836L; "latin" -> 7862832L; else -> error("Unknown model") }
        if (!target.exists() || target.length() != expected) {
            val temp = File(context.filesDir, "handwriting_${group}_$filename.tmp")
            context.assets.open(asset).use { input -> temp.outputStream().use { input.copyTo(it) } }
            check(temp.length() == expected)
            if (target.exists()) check(target.delete())
            check(temp.renameTo(target))
        }
        return target
    }

    private data class Bounds(val left: Int, val top: Int, val right: Int, val bottom: Int)

    private fun lineBounds(image: Bitmap): List<Bounds> {
        val pixels = IntArray(width * height)
        image.getPixels(pixels, 0, width, 0, 0, width, height)
        val used = BooleanArray(height)
        for (y in 0 until height) {
            for (x in 0 until width) if (Color.red(pixels[y * width + x]) < 200) { used[y] = true; break }
        }
        val groups = mutableListOf<Pair<Int, Int>>()
        var start = -1
        var last = -1
        for (y in 0 until height) if (used[y]) {
            if (start < 0) start = y
            // Korean syllables often have separated upper/lower strokes. A
            // fixed 28px gap split one syllable into several unrelated lines.
            else if (y - last > max(28, width / 16)) { groups.add(Pair(start, last)); start = y }
            last = y
        }
        if (start >= 0) groups.add(Pair(start, last))
        require(groups.size <= 80) { "Too many lines" }
        return groups.mapNotNull { (top, bottom) ->
            var left = width; var right = -1
            for (y in top..bottom) for (x in 0 until width) {
                if (Color.red(pixels[y * width + x]) < 200) { left = min(left, x); right = max(right, x) }
            }
            if (right < left) null else Bounds(max(0, left - 12), max(0, top - 12), min(width, right + 13), min(height, bottom + 13))
        }
    }

    private fun recognizeLine(source: Bitmap, b: Bounds, session: OrtSession, dictionary: List<String>): String {
        val crop = Bitmap.createBitmap(source, b.left, b.top, b.right - b.left, b.bottom - b.top)
        val targetHeight = 48
        val targetWidth = min(2048, max(32, ceil(crop.width.toDouble() * targetHeight / crop.height).toInt()))
        val resized = Bitmap.createScaledBitmap(crop, targetWidth, targetHeight, true)
        try {
            val pixels = IntArray(targetWidth * targetHeight)
            resized.getPixels(pixels, 0, targetWidth, 0, 0, targetWidth, targetHeight)
            val input = FloatArray(3 * pixels.size)
            for (i in pixels.indices) {
                val p = pixels[i]
                input[i] = Color.red(p) / 127.5f - 1f
                input[pixels.size + i] = Color.green(p) / 127.5f - 1f
                input[2 * pixels.size + i] = Color.blue(p) / 127.5f - 1f
            }
            OnnxTensor.createTensor(env, FloatBuffer.wrap(input), longArrayOf(1, 3, targetHeight.toLong(), targetWidth.toLong())).use { tensor ->
                session.run(mapOf(session.inputNames.first() to tensor)).use { result ->
                    @Suppress("UNCHECKED_CAST")
                    val sequence = (result[0].value as Array<Array<FloatArray>>)[0]
                    val text = StringBuilder()
                    var previous = -1
                    for (scores in sequence) {
                        var best = 0
                        for (i in 1 until scores.size) if (scores[i] > scores[best]) best = i
                        if (best != 0 && best != previous) {
                            val index = best - 1
                            if (index in dictionary.indices) text.append(dictionary[index])
                            else if (index == dictionary.size) text.append(' ')
                        }
                        previous = best
                    }
                    return Normalizer.normalize(text.toString(), Normalizer.Form.NFC)
                }
            }
        } finally { if (resized !== crop) resized.recycle(); crop.recycle() }
    }
}
