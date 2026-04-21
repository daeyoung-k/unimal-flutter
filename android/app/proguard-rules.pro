# Naver Login SDK
-keep class com.navercorp.nid.** { *; }
-keep interface com.navercorp.nid.** { *; }
-keep class com.nhn.android.naverlogin.** { *; }
-keep interface com.nhn.android.naverlogin.** { *; }

# Preserve generic type signatures (fixes ClassCastException: Class cannot be cast to ParameterizedType)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Gson
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
