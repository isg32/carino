package com.isg32.carino

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Notification dots: which apps have notifications worth a dot, and how
 * many. Follows Launcher3: a notification counts when its app allows dots
 * (the user's per-app setting), it isn't a group summary and it isn't an
 * ongoing one (music, navigation, downloads). Nothing is stored or sent;
 * the counts live only in memory.
 */
class CarinoNotifications : NotificationListenerService() {

    override fun onListenerConnected() {
        instance = this
        publish()
    }

    override fun onListenerDisconnected() {
        instance = null
        counts = emptyMap()
        onChange?.invoke(counts)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) = publish()

    override fun onNotificationRemoved(sbn: StatusBarNotification?) = publish()

    override fun onNotificationRankingUpdate(rankingMap: RankingMap?) = publish()

    private fun publish() {
        val active = try {
            activeNotifications ?: emptyArray()
        } catch (_: Exception) {
            emptyArray()
        }
        val ranking = currentRanking
        val next = mutableMapOf<String, Int>()
        for (sbn in active) {
            val n = sbn.notification
            if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) continue
            if (n.flags and Notification.FLAG_ONGOING_EVENT != 0) continue
            val r = Ranking()
            if (ranking != null && ranking.getRanking(sbn.key, r) && !r.canShowBadge()) continue
            next[sbn.packageName] = (next[sbn.packageName] ?: 0) + 1
        }
        if (next != counts) {
            counts = next
            onChange?.invoke(counts)
        }
    }

    companion object {
        @Volatile
        var counts: Map<String, Int> = emptyMap()
            private set

        private var instance: CarinoNotifications? = null

        /** Called on the main thread when the counts change. */
        var onChange: ((Map<String, Int>) -> Unit)? = null

        fun hasAccess(context: Context): Boolean {
            val me = ComponentName(context, CarinoNotifications::class.java).flattenToString()
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners",
            ) ?: return false
            return enabled.split(':').any { it == me }
        }
    }
}
