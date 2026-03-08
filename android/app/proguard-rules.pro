# ─── Razorpay ─────────────────────────────────────────────────────────────────
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/*
-keepclasseswithmembers class * {
    public void onPayment*(...);
}

# ─── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# ─── Firebase ─────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ─── Agora ────────────────────────────────────────────────────────────────────
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# ─── Socket.IO ────────────────────────────────────────────────────────────────
-dontwarn okio.**
-dontwarn javax.annotation.**
