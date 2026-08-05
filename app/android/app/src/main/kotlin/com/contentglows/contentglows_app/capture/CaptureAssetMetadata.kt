package com.contentglows.app.capture

import android.content.Context
import android.os.Environment
import java.io.File
import java.util.UUID

object CaptureAssetMetadata {
    fun screenshotsDir(context: Context): File {
        return File(context.getExternalFilesDir(Environment.DIRECTORY_PICTURES) ?: context.filesDir, "captures")
            .apply { mkdirs() }
    }

    fun recordingsDir(context: Context): File {
        return File(context.getExternalFilesDir(Environment.DIRECTORY_MOVIES) ?: context.filesDir, "captures")
            .apply { mkdirs() }
    }

    fun newScreenshotFile(context: Context): File {
        return File(screenshotsDir(context), "capture-${System.currentTimeMillis()}-${UUID.randomUUID()}.png")
    }

    fun newRecordingFile(context: Context): File {
        return File(recordingsDir(context), "capture-${System.currentTimeMillis()}-${UUID.randomUUID()}.mp4")
    }

    fun mapForFile(
        file: File,
        kind: String,
        mimeType: String,
        createdAt: Long,
        durationMs: Long?,
        width: Int,
        height: Int,
        microphoneEnabled: Boolean,
        captureScopeLabel: String
    ): Map<String, Any?> {
        return mapOf(
            "id" to file.nameWithoutExtension,
            "kind" to kind,
            "path" to file.absolutePath,
            "mimeType" to mimeType,
            "createdAt" to createdAt,
            "durationMs" to durationMs,
            "width" to width,
            "height" to height,
            "byteSize" to if (file.exists()) file.length() else 0L,
            "microphoneEnabled" to microphoneEnabled,
            "captureScopeLabel" to captureScopeLabel
        )
    }
}
