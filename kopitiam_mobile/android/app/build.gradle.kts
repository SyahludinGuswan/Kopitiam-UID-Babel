import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}
val isReleaseTask = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (isReleaseTask && !keystorePropertiesFile.exists()) {
    throw GradleException(
        "Release signing Kopitiam belum dikonfigurasi. " +
            "Ambil secret dari secret store lalu buat android/key.properties dan keystore release lokal."
    )
}

fun requiredReleaseSigningProperty(name: String): String {
    val value = keystoreProperties.getProperty(name)?.trim()
    if (value.isNullOrEmpty()) {
        throw GradleException("$name wajib diisi pada android/key.properties untuk build release.")
    }
    return value
}

android {
    namespace = "id.co.uidbabel.kopitiam"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "id.co.uidbabel.kopitiam"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (isReleaseTask) {
                val configuredStoreFile = rootProject.file(requiredReleaseSigningProperty("storeFile"))
                if (!configuredStoreFile.isFile) {
                    throw GradleException("Keystore release tidak ditemukan pada: ${configuredStoreFile.path}")
                }
                storeFile = configuredStoreFile
                storePassword = requiredReleaseSigningProperty("storePassword")
                keyAlias = requiredReleaseSigningProperty("keyAlias")
                keyPassword = requiredReleaseSigningProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (isReleaseTask) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.concurrent:concurrent-futures:1.2.0")
}
