package com.compress.all.flutter_compress

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import java.util.concurrent.atomic.AtomicInteger

/**
 * Keeps compression alive while the app is backgrounded. Started when a job
 * begins and stopped when the queue drains. The notification is intentionally
 * minimal — apps can localize/replace it in their own manifest if needed.
 */
class CompressionForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_NOT_STICKY
    }

    private fun buildNotification(): Notification {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Video compression",
                NotificationManager.IMPORTANCE_LOW,
            )
            nm.createNotificationChannel(channel)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Compressing video")
            .setContentText("This continues in the background")
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val TAG = "FlutterCompress"
        private const val CHANNEL_ID = "flutter_compress_channel"
        private const val NOTIFICATION_ID = 0x7C01

        /**
         * Number of jobs currently holding the service up. A plain boolean would
         * let one engine's `stop` kill the notification while another engine is
         * still encoding (multi-engine hosts, e.g. multi-window).
         */
        private val holders = AtomicInteger(0)

        fun start(context: Context) {
            if (holders.getAndIncrement() > 0) return
            val intent = Intent(context, CompressionForegroundService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: RuntimeException) {
                // The host app may have stripped FOREGROUND_SERVICE from the
                // merged manifest (SecurityException), or Android may refuse the
                // start outright (ForegroundServiceStartNotAllowedException on
                // API 31+). Neither should abort the encode: it just won't
                // survive backgrounding.
                holders.decrementAndGet()
                Log.w(TAG, "Foreground service unavailable; encoding without background protection", e)
            }
        }

        fun stop(context: Context) {
            // Guard against an unmatched stop (e.g. a failed start above)
            // dropping the count below zero.
            if (holders.get() <= 0 || holders.decrementAndGet() > 0) return
            runCatching {
                context.stopService(Intent(context, CompressionForegroundService::class.java))
            }.onFailure { Log.w(TAG, "Could not stop foreground service", it) }
        }
    }
}
