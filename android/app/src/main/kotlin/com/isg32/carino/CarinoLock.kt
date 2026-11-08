package com.isg32.carino

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent

/**
 * Double-tap to lock. An accessibility service is the one way an app can
 * lock the screen without device admin (which would force the PIN instead
 * of a fingerprint on the next unlock). This one only ever performs the
 * lock action; it reads nothing.
 */
class CarinoLock : AccessibilityService() {

    override fun onServiceConnected() {
        instance = this
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    companion object {
        private var instance: CarinoLock? = null

        /** Locks the screen; false if the service isn't turned on. */
        fun lock(): Boolean =
            instance?.performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN) ?: false

        fun isOn(context: Context): Boolean {
            val me = ComponentName(context, CarinoLock::class.java).flattenToString()
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            return enabled.split(':').any { it.equals(me, ignoreCase = true) }
        }
    }
}
