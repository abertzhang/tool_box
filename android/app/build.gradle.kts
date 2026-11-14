import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 读取 android/key.properties 中的上传密钥配置（该文件已 gitignore，切勿入库）。
// 文件不存在时 useReleaseSigning=false，release 构建回退到 debug 签名，本地调试不受影响。
val keystorePropertiesFile = rootProject.file("key.properties")
val useReleaseSigning = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (useReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "uk.aknot.toolbox"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "uk.aknot.toolbox"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // 保持 Flutter 默认最低版本（当前为 24）：本工程不含端侧大模型，
        // camera / geolocator / permission_handler / isar 等插件的下限均低于 24，无需上调。
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 正式发布签名：使用 android/upload-keystore.jks（Play App Signing 的上传密钥）。
    // 仅当 android/key.properties 存在时创建 release 签名配置，否则保持 debug 回退，
    // 避免本地缺少 key.properties 时 debug / 其他构建直接报错。
    signingConfigs {
        if (useReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 上架 Play / 分发 release AAB 时使用的正式签名（upload key）。
            signingConfig = if (useReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // 显式关闭 release 的代码压缩 / 混淆（R8）。
            // 背景：本工程未配置任何 proguard 规则文件，但 release 构建默认会跑 R8，
            // 导致依赖反射的库被改名或剔除 —— 实测表现为启动即在 ContentProvider 阶段崩溃：
            //   java.lang.RuntimeException: Unable to get provider androidx.startup.InitializationProvider
            //   Caused by: Failed to create an instance of androidx.work.impl.WorkDatabase
            // （WorkManager 的 Room 数据库 WorkDatabase_Impl 被混淆，反射找不到/建不了实例）
            // 而 debug 不混淆所以一切正常，故这是典型的 release-only 崩溃。
            // 关闭后 release 与 debug 保留相同的类结构，规避这一类问题。
            // ⚠️ 若日后需要开启瘦身，必须先补齐 Room / Isar / Hive / Supabase 等的
            //    proguard keep 规则，再改回 isMinifyEnabled = true，否则会再次闪退。
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
