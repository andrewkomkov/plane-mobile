package com.slimshaggy.plane_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build

/**
 * The system's answer to an install session.
 *
 * The install itself is the system's business and the user confirms it: what
 * arrives here is [PackageInstaller.STATUS_PENDING_USER_ACTION] carrying a
 * ready-made dialog, which only has to be shown.
 */
class InstallReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION = "com.slimshaggy.plane_mobile.INSTALL_RESULT"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, Int.MIN_VALUE)
        if (status != PackageInstaller.STATUS_PENDING_USER_ACTION) return

        // The dialog is launched while the app is on screen — the user has
        // just pressed the button — so the background activity-start
        // restriction does not apply here.
        val confirm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_INTENT)
        } ?: return

        runCatching {
            context.startActivity(confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }
}
