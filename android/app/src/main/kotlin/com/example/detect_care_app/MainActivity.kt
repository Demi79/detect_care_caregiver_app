package com.example.detect_care_caregiver_app

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import com.google.firebase.messaging.FirebaseMessaging
import android.util.Log

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (task.isSuccessful) {
                val token = task.result
                Log.d("FCM", "Token: $token")
                // Copy token này vào .env hoặc gửi lên server
            } else {
                Log.e("FCM", "Failed to get token: ${task.exception?.message}")
            }
        }
    }
}
