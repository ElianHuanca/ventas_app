import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clave de firma propia (android/key.properties, fuera de git). Sin ella cada
// PC firma con su propia clave de debug y los celulares rechazan la
// actualización ("signatures do not match"). Ver CLAUDE.md → Firma del APK.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val tieneClaveRelease = keystorePropertiesFile.exists()
if (tieneClaveRelease) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    logger.warn("⚠️ android/key.properties no existe: se firma con la clave de debug de esta PC. Los celulares con la app oficial NO podrán actualizar con este APK.")
}

android {
    namespace = "com.example.textiles_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.textiles_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (tieneClaveRelease) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        // Debug también se firma con la clave propia: así `flutter run` se
        // instala encima de la app oficial sin desinstalarla.
        val firma = if (tieneClaveRelease) signingConfigs.getByName("release")
                    else signingConfigs.getByName("debug")
        release {
            signingConfig = firma
        }
        debug {
            signingConfig = firma
        }
    }
}

flutter {
    source = "../.."
}
