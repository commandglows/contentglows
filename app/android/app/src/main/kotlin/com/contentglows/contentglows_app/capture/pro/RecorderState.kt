package com.contentglows.app.capture.pro

enum class RecorderState {
    IDLE,
    STARTING,
    RECORDING,
    PAUSED,
    STOPPING,
    FAILED,
    ;

    fun eventValue(): String = name.lowercase()
}

data class RecorderStatePayload(
    val type: String = "state",
    val state: RecorderState,
    val previousState: RecorderState? = null,
    val stopReason: String? = null,
    val failureCode: String? = null,
) {
    fun toEventMap(): Map<String, Any?> = buildMap {
        put("type", type)
        put("state", state.eventValue())
        previousState?.let {
            put("previousState", it.eventValue())
        }
        put("stopReason", stopReason)
        put("failureCode", failureCode)
    }
}
