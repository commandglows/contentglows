package com.contentglows.app.capture

import android.content.Context
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.WindowManager
import java.io.FileOutputStream

class ScreenShotCapture(private val context: Context) {
    fun capture(
        projection: MediaProjection,
        onSuccess: (Map<String, Any?>) -> Unit,
        onError: (String, String) -> Unit
    ) {
        val metrics = displayMetrics()
        val width = metrics.widthPixels.coerceAtLeast(1)
        val height = metrics.heightPixels.coerceAtLeast(1)
        val density = metrics.densityDpi
        val handler = Handler(Looper.getMainLooper())
        val imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        var virtualDisplay: VirtualDisplay? = null
        var finished = false

        fun cleanup() {
            try {
                virtualDisplay?.release()
            } catch (_: Exception) {
            }
            try {
                imageReader.close()
            } catch (_: Exception) {
            }
            try {
                projection.stop()
            } catch (_: Exception) {
            }
        }

        val projectionCallback = object : MediaProjection.Callback() {
            override fun onStop() {
                if (!finished) {
                    finished = true
                    cleanup()
                    onError("capture_canceled", "Android stopped screen capture before a frame was saved.")
                }
            }
        }
        projection.registerCallback(projectionCallback, handler)

        imageReader.setOnImageAvailableListener({ reader ->
            if (finished) return@setOnImageAvailableListener
            val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
            finished = true
            try {
                val plane = image.planes[0]
                val imageWidth = image.width
                val imageHeight = image.height
                val buffer = plane.buffer
                val pixelStride = plane.pixelStride
                val rowStride = plane.rowStride
                val rowPadding = rowStride - pixelStride * imageWidth
                val paddedWidth = imageWidth + rowPadding / pixelStride
                val paddedBitmap = Bitmap.createBitmap(paddedWidth, imageHeight, Bitmap.Config.ARGB_8888)
                paddedBitmap.copyPixelsFromBuffer(buffer)
                val bitmap = Bitmap.createBitmap(paddedBitmap, 0, 0, imageWidth, imageHeight)
                paddedBitmap.recycle()

                val output = CaptureAssetMetadata.newScreenshotFile(context)
                FileOutputStream(output).use { stream ->
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                }
                bitmap.recycle()
                image.close()
                cleanup()
                onSuccess(
                    CaptureAssetMetadata.mapForFile(
                        file = output,
                        kind = "screenshot",
                        mimeType = "image/png",
                        createdAt = System.currentTimeMillis(),
                        durationMs = null,
                        width = imageWidth,
                        height = imageHeight,
                        microphoneEnabled = false,
                        captureScopeLabel = "system-selected"
                    )
                )
            } catch (error: Exception) {
                try {
                    image.close()
                } catch (_: Exception) {
                }
                cleanup()
                onError("capture_failed", error.message ?: "Screenshot capture failed.")
            }
        }, handler)

        handler.postDelayed({
            if (!finished) {
                finished = true
                cleanup()
                onError("capture_timeout", "No screen frame arrived before the screenshot timeout.")
            }
        }, 4_000)

        try {
            virtualDisplay = projection.createVirtualDisplay(
                "ContentGlowsScreenshot",
                width,
                height,
                density,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                imageReader.surface,
                null,
                handler
            )
        } catch (error: Exception) {
            if (!finished) {
                finished = true
                cleanup()
                onError("capture_failed", error.message ?: "Could not create Android virtual display.")
            }
        }
    }

    private fun displayMetrics(): DisplayMetrics {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay.getRealMetrics(metrics)
        return metrics
    }
}
