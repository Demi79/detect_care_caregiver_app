plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.detect_care_caregiver_app"
    compileSdk = flutter.compileSdkVersion
    // 1. Nâng NDK lên 27.0.12077973
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Java 11
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // 2. Bật core library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.detect_care_caregiver_app"
        minSdk     = flutter.minSdkVersion
        targetSdk  = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // 3. Thêm desugar_jdk_libs để hỗ trợ desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // Firebase Cloud Messaging
    implementation(platform("com.google.firebase:firebase-bom:32.2.3"))
    implementation("com.google.firebase:firebase-messaging-ktx")
}

flutter {
    source = "../.."
}
