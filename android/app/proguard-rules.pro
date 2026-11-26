# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core / deferred components (referenced optionally by Flutter embedding)
-dontwarn com.google.android.play.core.**

# speech_to_text plugin classes
-keep class com.csdcorp.speech_to_text.** { *; }

# flutter_local_notifications & Gson TypeToken reflection
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
