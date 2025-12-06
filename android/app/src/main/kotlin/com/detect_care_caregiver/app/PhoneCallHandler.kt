package com.detect_care_caregiver.app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.util.Log
import androidx.core.app.ActivityCompat

/**
 * Helper to perform phone calls from native Android side.
 *
 * If CALL_PHONE permission is granted, this will attempt to place a call
 * using ACTION_CALL. If the permission is missing it will fall back to
 * ACTION_DIAL which opens the dialer pre-filled with the number.
 */
class PhoneCallHandler(private val activity: Activity) {
    private val TAG = "PhoneCallHandler"

    fun makeDirectCall(number: String): Boolean {
        try {
            val uri = Uri.parse("tel:$number")

            return if (ActivityCompat.checkSelfPermission(
                    activity,
                    Manifest.permission.CALL_PHONE
                ) == PackageManager.PERMISSION_GRANTED
            ) {
                val intent = Intent(Intent.ACTION_CALL, uri)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                activity.startActivity(intent)
                true
            } else {
                // Permission not granted — open dialer as a safe fallback.
                val dialIntent = Intent(Intent.ACTION_DIAL, uri)
                dialIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                activity.startActivity(dialIntent)
                true
            }
        } catch (t: Throwable) {
            Log.e(TAG, "makeDirectCall failed", t)
            return false
        }
    }
}
