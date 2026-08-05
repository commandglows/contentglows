import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val clerkPublishableKey = providers.environmentVariable("CLERK_PUBLISHABLE_KEY")
    .orElse(providers.gradleProperty("CLERK_PUBLISHABLE_KEY"))
    .orElse("")
    .get()
val contentGlowsAuthEnabled = providers.gradleProperty("contentglowsAuthEnabled")
    .map { it.toBoolean() }
    .orElse(true)
    .get()
val releaseKeystorePath = providers.environmentVariable("ANDROID_KEYSTORE_PATH").orElse("").get()
val releaseKeystorePassword = providers.environmentVariable("ANDROID_KEYSTORE_PASSWORD").orElse("").get()
val releaseKeyAlias = providers.environmentVariable("ANDROID_KEY_ALIAS").orElse("").get()
val releaseKeyPassword = providers.environmentVariable("ANDROID_KEY_PASSWORD").orElse("").get()

if (contentGlowsAuthEnabled && clerkPublishableKey.isBlank()) {
    throw GradleException(
        "CLERK_PUBLISHABLE_KEY is required for auth-enabled Android builds. " +
            "Provide it through the environment or an ignored Gradle property.",
    )
}

android {
    namespace = "com.contentglows.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.contentglows.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Clerk Android requires API 24. Keep Flutter's higher value when it changes.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures {
        buildConfig = true
    }

    packaging {
        resources {
            // Duplicated by Clerk's OkHttp stack and jspecify; unused by Android at runtime.
            excludes += "/META-INF/versions/9/OSGI-INF/MANIFEST.MF"
        }
    }

    defaultConfig {
        buildConfigField("String", "CLERK_PUBLISHABLE_KEY", "\"$clerkPublishableKey\"")
    }

    signingConfigs {
        create("contentglowsRelease") {
            if (releaseKeystorePath.isBlank() || releaseKeystorePassword.isBlank() ||
                releaseKeyAlias.isBlank() || releaseKeyPassword.isBlank()
            ) {
                throw GradleException(
                    "Stable release signing is required. Configure ANDROID_KEYSTORE_PATH, " +
                        "ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, and ANDROID_KEY_PASSWORD.",
                )
            }
            storeFile = file(releaseKeystorePath)
            storePassword = releaseKeystorePassword
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("contentglowsRelease")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    // API-only: Flutter owns the UI; Clerk owns native session persistence.
    implementation("com.clerk:clerk-android-api:1.0.36")
}

flutter {
    source = "../.."
}
