package com.slimshaggy.plane_mobile

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hands a downloaded APK to Android's own package installer.
 *
 * The app is installed from a release APK, so there is no store to deliver an
 * update through. Before this, the update button opened a browser and the user
 * had to find the file in Downloads and run it themselves.
 *
 * Nothing here installs anything. The APK is written into an installer session
 * and committed; the system then shows its own "update this app?" dialog and
 * does the work — including refusing a package signed with a key other than
 * the one that signed what is already installed. That refusal is the check
 * that matters, and it is not ours.
 */
class UpdateInstaller(
    private val activity: () -> Activity?,
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "plane_mobile/updater"

        fun register(messenger: BinaryMessenger, activity: () -> Activity?, context: Context) {
            MethodChannel(messenger, CHANNEL)
                .setMethodCallHandler(UpdateInstaller(activity, context))
        }
    }

    override fun onMethodCall(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "canInstall" -> result.success(canRequestInstalls())

            "requestInstallPermission" -> {
                // Granted once, by hand, in system settings — there is no
                // runtime prompt for it.
                val target = activity() ?: context
                val intent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${context.packageName}"),
                )
                if (target !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                runCatching { target.startActivity(intent) }
                    .onSuccess { result.success(null) }
                    .onFailure { result.error("no_settings", it.message, null) }
            }

            "install" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrEmpty()) {
                    result.error("no_path", "No APK path given", null)
                    return
                }
                if (!canRequestInstalls()) {
                    result.error(
                        "permission",
                        "Allow installing unknown apps for Plane first",
                        null,
                    )
                    return
                }
                runCatching { commit(File(path)) }
                    .onSuccess { result.success(null) }
                    .onFailure { result.error("install_failed", it.message, null) }
            }

            else -> result.notImplemented()
        }
    }

    private fun canRequestInstalls(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    private fun commit(apk: File) {
        require(apk.isFile && apk.length() > 0) { "The downloaded file is not there" }

        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL,
        ).apply { setAppPackageName(context.packageName) }

        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            session.openWrite("apk", 0, apk.length()).use { output ->
                apk.inputStream().use { it.copyTo(output) }
                session.fsync(output)
            }
            val callback = PendingIntent.getBroadcast(
                context,
                sessionId,
                Intent(context, InstallReceiver::class.java)
                    .setAction(InstallReceiver.ACTION)
                    .setPackage(context.packageName),
                PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            session.commit(callback.intentSender)
        }
    }
}
