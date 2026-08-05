package com.contentglows.app

import android.app.Application
import com.clerk.api.Clerk

/** Owns Clerk initialization for the Android process. Never log the publishable key. */
class ContentGlowsApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val key = BuildConfig.CLERK_PUBLISHABLE_KEY.trim()
        check(key.isNotEmpty()) {
            "CLERK_PUBLISHABLE_KEY is missing from this Android build."
        }
        Clerk.initialize(this, publishableKey = key)
    }
}
