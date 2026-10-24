# Flutter plugins (seguridad extra)
-keep class io.flutter.plugins.** { *; }

# AndroidX WorkManager (utilizado por home_widget / tareas en segundo plano)
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keepnames class androidx.work.impl.WorkDatabase { *; }

# AndroidX Room
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class * extends androidx.room.RoomOpenHelper$Delegate { *; }
-dontwarn androidx.room.paging.**

# AndroidX Startup
-keep class androidx.startup.** { *; }
-keep class * extends androidx.startup.Initializer { *; }

# Home Widget plugin
-keep class es.antonborri.home_widget.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Licencias de Apklis
-keep class cu.uci.android.apklis_license_validator.** { *; }
-dontwarn org.bouncycastle.jsse.BCSSLParameters
-dontwarn org.bouncycastle.jsse.BCSSLSocket
-dontwarn org.bouncycastle.jsse.provider.BouncyCastleJsseProvider
-dontwarn org.conscrypt.Conscrypt$Version
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.ConscryptHostnameVerifier
-dontwarn org.openjsse.javax.net.ssl.SSLParameters
-dontwarn org.openjsse.javax.net.ssl.SSLSocket
-dontwarn org.openjsse.net.ssl.OpenJSSE