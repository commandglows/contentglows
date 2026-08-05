package com.contentglows.app.capture

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.util.Base64
import java.io.File
import java.io.FileNotFoundException

class CaptureFileProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun getType(uri: Uri): String? = uri.getQueryParameter("m") ?: "application/octet-stream"

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?
    ): Cursor {
        val file = fileForUri(uri)
        val cursor = MatrixCursor(arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE))
        cursor.addRow(arrayOf(file.name, file.length()))
        return cursor
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") {
            throw SecurityException("Capture files are shared read-only.")
        }
        val file = fileForUri(uri)
        if (!file.exists()) {
            throw FileNotFoundException(file.absolutePath)
        }
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = 0

    private fun fileForUri(uri: Uri): File {
        val context = context ?: throw FileNotFoundException("No provider context.")
        val encoded = uri.getQueryParameter("p") ?: throw FileNotFoundException("Missing file token.")
        val path = String(Base64.decode(encoded, Base64.URL_SAFE or Base64.NO_WRAP), Charsets.UTF_8)
        val file = File(path).canonicalFile
        val allowedRoots = listOfNotNull(
            context.filesDir,
            context.getExternalFilesDir(null)
        ).map { it.canonicalFile }
        if (allowedRoots.none { file.path == it.path || file.path.startsWith("${it.path}/") }) {
            throw SecurityException("File is outside ContentGlows capture storage.")
        }
        return file
    }

    companion object {
        fun uriForFile(context: android.content.Context, file: File, mimeType: String): Uri {
            val token = Base64.encodeToString(
                file.canonicalPath.toByteArray(Charsets.UTF_8),
                Base64.URL_SAFE or Base64.NO_WRAP
            )
            return Uri.Builder()
                .scheme("content")
                .authority("${context.packageName}.capture.files")
                .appendPath(file.name)
                .appendQueryParameter("p", token)
                .appendQueryParameter("m", mimeType)
                .build()
        }
    }
}
