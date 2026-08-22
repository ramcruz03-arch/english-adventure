# Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_tts
-keep class com.tundralabs.fluttertts.** { *; }
-keep class android.speech.tts.** { *; }

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# Keep annotations used by plugin registration
-keepattributes *Annotation*
