package com.contentglows.app.auth

import com.clerk.api.Clerk
import com.clerk.api.network.serialization.ClerkResult
import com.clerk.api.sso.OAuthProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/** A narrow Flutter boundary: Clerk session state remains native and tokens are never logged. */
class ClerkAuthChannel(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var activeAuthentication: Job? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> launch(result) { initializedPayload() }
            "restoreSession" -> launch(result) { sessionPayloadOrNull() }
            "getFreshToken" -> launch(result) { freshTokenOrNull() }
            "signOut" -> launch(result) { signOut(); mapOf("signedOut" to true) }
            "signInWithGoogle" -> signInWithGoogle(result)
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        activeAuthentication?.cancel()
        activeAuthentication = null
        scope.cancel()
        channel.setMethodCallHandler(null)
    }

    private fun signInWithGoogle(result: MethodChannel.Result) {
        if (activeAuthentication?.isActive == true) {
            result.error("auth_in_progress", "A native authentication operation is already active.", null)
            return
        }
        activeAuthentication = scope.launch {
            try {
                requireReady()
                when (val outcome = Clerk.auth.signInWithOAuth(OAuthProvider.GOOGLE)) {
                    is ClerkResult.Success -> {
                        if (Clerk.session == null || Clerk.user == null) {
                            result.error(
                                "oauth_incomplete",
                                "Google sign-in returned to the app but no Clerk session was activated. Please try again.",
                                null,
                            )
                        } else {
                            result.success(requireSessionPayload())
                        }
                    }
                    is ClerkResult.Failure -> result.error(
                        errorCode(outcome.throwable),
                        errorMessage(outcome.throwable, "Native Google sign-in did not complete."),
                        null,
                    )
                }
            } catch (error: Throwable) {
                result.error(
                    errorCode(error),
                    errorMessage(error, "Native Google sign-in did not complete."),
                    null,
                )
            } finally {
                activeAuthentication = null
            }
        }
    }

    private fun launch(result: MethodChannel.Result, block: suspend () -> Any?) {
        scope.launch {
            try {
                result.success(block())
            } catch (error: Throwable) {
                result.error(errorCode(error), "Native Clerk operation failed.", null)
            }
        }
    }

    private suspend fun initializedPayload(): Map<String, Boolean> {
        requireReady()
        return mapOf("ready" to true)
    }

    private suspend fun sessionPayloadOrNull(): Map<String, String?>? {
        requireReady()
        if (Clerk.session == null) return null
        return requireSessionPayload()
    }

    private suspend fun requireSessionPayload(): Map<String, String?> {
        val token = freshTokenOrNull() ?: throw IllegalStateException("No active Clerk token.")
        val user = Clerk.user ?: throw IllegalStateException("No active Clerk user.")
        return mapOf(
            "bearerToken" to token,
            "userId" to user.id,
            "email" to user.primaryEmailAddress?.emailAddress,
        )
    }

    private suspend fun freshTokenOrNull(): String? {
        requireReady()
        return when (val outcome = Clerk.auth.getToken()) {
            is ClerkResult.Success -> outcome.value.takeIf { it.isNotBlank() }
            is ClerkResult.Failure -> null
        }
    }

    private suspend fun signOut() {
        requireReady()
        when (val outcome = Clerk.auth.signOut()) {
            is ClerkResult.Success -> Unit
            is ClerkResult.Failure -> throw IllegalStateException("Native sign-out did not complete.")
        }
    }

    private suspend fun requireReady() {
        if (!awaitReady()) throw ClerkNotReadyException()
    }

    private suspend fun awaitReady(): Boolean =
        withTimeoutOrNull(INITIALIZATION_TIMEOUT_MS) { Clerk.isInitialized.first { it } } != null

    private fun errorCode(error: Throwable?): String = when {
        error is ClerkNotReadyException -> "clerk_not_ready"
        error?.javaClass?.simpleName?.contains("Cancellation", ignoreCase = true) == true -> "cancelled"
        error?.javaClass?.simpleName?.contains("Credential", ignoreCase = true) == true -> "credential_error"
        else -> "native_auth_error"
    }

    private fun errorMessage(error: Throwable?, fallback: String): String = when {
        error is ClerkNotReadyException ->
            "Clerk native initialization did not complete. Verify that Clerk Native API is enabled and that this APK has network access, then retry."
        else -> fallback
    }

    private class ClerkNotReadyException : IllegalStateException()

    companion object {
        const val CHANNEL_NAME = "com.contentglows.app/clerk_auth"
        private const val INITIALIZATION_TIMEOUT_MS = 15_000L
    }
}
