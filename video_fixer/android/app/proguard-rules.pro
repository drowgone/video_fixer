# Preserve FFmpegKit classes and interfaces from being obfuscated or stripped
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.antonkarpenko.ffmpegkit.** { *; }

-dontwarn com.arthenica.ffmpegkit.**
-dontwarn com.antonkarpenko.ffmpegkit.**

# Keep ABI Detection
-keep class com.arthenica.ffmpegkit.AbiDetect { *; }
-keep class com.antonkarpenko.ffmpegkit.AbiDetect { *; }

# Keep all FFmpegKit sessions
-keep class com.arthenica.ffmpegkit.*Session { *; }
-keep class com.antonkarpenko.ffmpegkit.*Session { *; }

# Keep FFmpegKit callbacks
-keep class com.arthenica.ffmpegkit.*Callback { *; }
-keep class com.antonkarpenko.ffmpegkit.*Callback { *; }

# Preserve all public classes in ffmpegkit
-keep public class com.arthenica.ffmpegkit.** { public *; }
-keep public class com.antonkarpenko.ffmpegkit.** { public *; }

# Keep reflection-based access
-keepattributes *Annotation*, Signature, InnerClasses

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
