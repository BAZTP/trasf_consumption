package com.baztp.transf_consumption

import android.app.Notification
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class TransfNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "TransfNotifService"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        try {
            val packageName = sbn.packageName ?: ""
            val notification = sbn.notification ?: return
            val extras = notification.extras ?: return

            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
            var text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
            val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""

            if (bigText.isNotEmpty() && bigText.length > text.length) {
                text = bigText
            }

            if (text.isEmpty() && title.isEmpty()) return

            Log.d(TAG, "Notification received from: $packageName, title: $title, text: $text")

            val notificationData = mapOf(
                "packageName" to packageName,
                "title" to title,
                "text" to text
            )

            // Enviar a Flutter a través del canal en el hilo principal
            Handler(Looper.getMainLooper()).post {
                MainActivity.channel?.invokeMethod("onNotificationReceived", notificationData)
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error processing notification: ${e.message}", e)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
    }
}
