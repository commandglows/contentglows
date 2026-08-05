package com.contentglows.app.media

import android.app.Activity
import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Keeps device media identity entirely on Android. Flutter receives a cache
 * copy for upload plus the original MediaStore URI, which is never sent to
 * ContentGlows servers and can only be deleted through Android's consent UI.
 */
class AndroidMediaLibraryChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingDeleteResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickMedia" -> pickMedia(result)
            "deleteMedia" -> deleteMedia(call, result)
            else -> result.notImplemented()
        }
    }

    private fun pickMedia(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("selection_in_progress", "A media selection is already open.", null)
            return
        }
        pendingPickResult = result
        val intent = Intent(Intent.ACTION_PICK).apply {
            data = MediaStore.Files.getContentUri("external")
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*"))
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        activity.startActivityForResult(intent, PICK_MEDIA_REQUEST)
    }

    private fun deleteMedia(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.error(
                "unsupported_android_version",
                "Deleting imported media requires Android 11 or later.",
                null,
            )
            return
        }
        if (pendingDeleteResult != null) {
            result.error("deletion_in_progress", "A device deletion is already awaiting confirmation.", null)
            return
        }
        val rawUri = call.argument<String>("contentUri")
        val uri = rawUri?.let(Uri::parse)
        if (!isMediaStoreUri(uri)) {
            result.error("invalid_media_uri", "Only MediaStore media can be deleted.", null)
            return
        }
        try {
            val request: PendingIntent = MediaStore.createDeleteRequest(
                activity.contentResolver,
                listOf(uri),
            )
            pendingDeleteResult = result
            activity.startIntentSenderForResult(
                request.intentSender,
                DELETE_MEDIA_REQUEST,
                null,
                0,
                0,
                0,
            )
        } catch (error: Exception) {
            result.error("device_delete_unavailable", "Android could not request deletion for this media.", null)
        }
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return when (requestCode) {
            PICK_MEDIA_REQUEST -> {
                handlePickResult(resultCode, data)
                true
            }
            DELETE_MEDIA_REQUEST -> {
                pendingDeleteResult?.success(resultCode == Activity.RESULT_OK)
                pendingDeleteResult = null
                true
            }
            else -> false
        }
    }

    private fun handlePickResult(resultCode: Int, data: Intent?) {
        val result = pendingPickResult ?: return
        pendingPickResult = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<Map<String, Any>>())
            return
        }
        val uris = buildList {
            data.data?.let(::add)
            data.clipData?.let { clip ->
                for (index in 0 until clip.itemCount) add(clip.getItemAt(index).uri)
            }
        }.distinct()
        if (uris.any { !isMediaStoreUri(it) }) {
            result.error(
                "unsupported_media_location",
                "Choose photos or videos from this Android device library.",
                null,
            )
            return
        }
        Thread {
            try {
                val files = uris.map(::copyForUpload)
                activity.runOnUiThread { result.success(files) }
            } catch (error: Exception) {
                activity.runOnUiThread {
                    result.error("media_copy_failed", "The selected media could not be prepared for upload.", null)
                }
            }
        }.start()
    }

    private fun copyForUpload(uri: Uri): Map<String, Any> {
        val resolver = activity.contentResolver
        val mimeType = resolver.getType(uri)?.takeIf {
            it.startsWith("image/") || it.startsWith("video/")
        } ?: throw IllegalArgumentException("Unsupported media type")
        val fileName = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
            ?.takeIf { it.isNotBlank() }
            ?: "media-${System.currentTimeMillis()}"
        val cacheDirectory = File(activity.cacheDir, "source-media-imports").apply { mkdirs() }
        val cacheFile = File.createTempFile("source-", "-${fileName.replace(Regex("[^A-Za-z0-9._-]"), "_")}", cacheDirectory)
        resolver.openInputStream(uri)?.use { input ->
            cacheFile.outputStream().use { output -> input.copyTo(output) }
        } ?: throw IllegalArgumentException("Media stream unavailable")
        return mapOf(
            "contentUri" to uri.toString(),
            "cachePath" to cacheFile.absolutePath,
            "fileName" to fileName,
            "mimeType" to mimeType,
            "sizeBytes" to cacheFile.length(),
        )
    }

    private fun isMediaStoreUri(uri: Uri?): Boolean =
        uri?.scheme == "content" && uri.authority == MediaStore.AUTHORITY

    fun dispose() {
        channel.setMethodCallHandler(null)
        pendingPickResult = null
        pendingDeleteResult = null
    }

    companion object {
        private const val CHANNEL_NAME = "contentglows/android_media_library"
        private const val PICK_MEDIA_REQUEST = 7041
        private const val DELETE_MEDIA_REQUEST = 7042
    }
}
