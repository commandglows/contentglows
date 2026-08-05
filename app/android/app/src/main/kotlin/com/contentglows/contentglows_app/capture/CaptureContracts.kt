package com.contentglows.app.capture

import io.flutter.plugin.common.MethodCall

data class CaptureOverlayConfig(
    val shape: String = "circle",
    val size: String = "medium",
) {
    fun toMap(): Map<String, Any> = mapOf(
        "shape" to shape,
        "size" to size,
    )
}

data class CaptureRecordingConfig(
    val requestedAudioMode: String = "screenOnly",
    val effectiveAudioMode: String = "screenOnly",
    val requestedCameraMode: String = "screenOnly",
    val effectiveCameraMode: String = "screenOnly",
    val overlayConfig: CaptureOverlayConfig = CaptureOverlayConfig(),
    val degradationFlags: List<String> = emptyList(),
    val startedWithForegroundOverlay: Boolean = false,
) {
    fun toEventMap(): Map<String, Any?> = mapOf(
        "effectiveAudioMode" to effectiveAudioMode,
        "effectiveCameraMode" to effectiveCameraMode,
        "overlayConfig" to overlayConfig.toMap(),
        "degraded" to degradationFlags.isNotEmpty(),
        "degradationFlags" to degradationFlags,
        "startedWithForegroundOverlay" to startedWithForegroundOverlay,
    )

    fun toAssetMap(): Map<String, Any?> = mapOf(
        "requestedAudioMode" to requestedAudioMode,
        "effectiveAudioMode" to effectiveAudioMode,
        "requestedCameraMode" to requestedCameraMode,
        "effectiveCameraMode" to effectiveCameraMode,
        "overlayConfig" to overlayConfig.toMap(),
        "degradationFlags" to degradationFlags,
        "startedWithForegroundOverlay" to startedWithForegroundOverlay,
    )

    companion object {
        fun fromMethodCall(call: MethodCall): CaptureRecordingConfig {
            val options = call.argument<Map<String, Any?>>("options") ?: emptyMap()
            val overlay = (options["overlayConfig"] as? Map<*, *>).orEmpty()
            return CaptureRecordingConfig(
                requestedAudioMode = options["audioMode"]?.toString() ?: "screenOnly",
                effectiveAudioMode = options["audioMode"]?.toString() ?: "screenOnly",
                requestedCameraMode = options["cameraMode"]?.toString() ?: "screenOnly",
                effectiveCameraMode = options["cameraMode"]?.toString() ?: "screenOnly",
                overlayConfig = CaptureOverlayConfig(
                    shape = overlay["shape"]?.toString() ?: "circle",
                    size = overlay["size"]?.toString() ?: "medium",
                ),
            )
        }
    }
}
