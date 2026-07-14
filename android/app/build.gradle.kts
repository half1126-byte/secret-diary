plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.secretdiary.secret_diary"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.secretdiary.secret_diary"
        // ML Kit digital ink + flutter_secure_storage 요구사항에 맞춘 최소 SDK
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 최신 AGP는 resValues가 기본 꺼져 있어 flavor별 app_name 정의에 필요.
    buildFeatures {
        resValues = true
    }

    // 한 저장소에서 두 앱: Re:Me(일기)와 ENTP(채팅 상담).
    // 앱 ID가 달라 폰에 나란히 설치된다.
    flavorDimensions += "app"
    productFlavors {
        create("reme") {
            dimension = "app"
            resValue("string", "app_name", "Re:Me")
        }
        create("coach") {
            dimension = "app"
            applicationId = "dev.secretdiary.coach"
            resValue("string", "app_name", "ENTP")
        }
    }

    buildTypes {
        release {
            // 개인 배포용 임시 서명 (Play 스토어 등록 시 릴리즈 키로 교체).
            signingConfig = signingConfigs.getByName("debug")
            // R8 코드 축소가 ML Kit 등 플러그인 클래스를 제거해
            // 실행 즉시 중단되는 문제를 막는다. APK가 조금 커지는 대신 안전.
            isMinifyEnabled = false
            isShrinkResources = false
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
