package com.isg32.carino

import android.app.Activity
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.LauncherApps
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.UserManager
import android.util.SizeF
import android.view.View
import android.widget.TextView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Widgets from other apps on the Widgets tab, hosted as Launcher3 does:
 * list the providers, bind a widget id (asking the user the first time),
 * run its configure screen if it has one, and draw it as an
 * AppWidgetHostView inside Flutter (see [WidgetViewFactory]).
 *
 * The host only listens for updates while Cariño is on screen.
 */
class CarinoWidgets(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "carino/widgets")
    val manager: AppWidgetManager = AppWidgetManager.getInstance(activity)
    val host = AppWidgetHost(activity.applicationContext, HOST_ID)
    private val launcherApps = activity.getSystemService(LauncherApps::class.java)
    private val users = activity.getSystemService(UserManager::class.java)
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()

    private var pending: MethodChannel.Result? = null
    private var pendingId = -1

    /** The views currently drawn, by widget id. */
    val views = mutableMapOf<Int, View>()

    init {
        channel.setMethodCallHandler(this)
        onResume()
    }

    fun onResume() {
        try {
            host.startListening()
        } catch (_: Exception) {
        }
    }

    fun onPause() {
        try {
            host.stopListening()
        } catch (_: Exception) {
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        onPause()
        worker.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "providers" -> worker.execute {
                    val list = try {
                        providers()
                    } catch (_: Exception) {
                        emptyList()
                    }
                    main.post { result.success(list) }
                }
                "preview" -> {
                    val info = find(call.argument<String>("provider")!!, call.argument<Number>("user")!!.toLong())
                    worker.execute {
                        val png = try {
                            info?.let { preview(it) }
                        } catch (_: Exception) {
                            null
                        }
                        main.post { result.success(png) }
                    }
                }
                "add" -> {
                    val info = find(call.argument<String>("provider")!!, call.argument<Number>("user")!!.toLong())
                    if (info == null) {
                        result.success(null)
                        return
                    }
                    val id = host.allocateAppWidgetId()
                    if (manager.bindAppWidgetIdIfAllowed(id, info.profile, info.provider, null)) {
                        configureOrFinish(id, result)
                    } else {
                        // First widget from this app: Android asks the user.
                        pending?.success(null)
                        pending = result
                        pendingId = id
                        val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_BIND)
                            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER, info.provider)
                            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER_PROFILE, info.profile)
                        activity.startActivityForResult(intent, REQUEST_BIND)
                    }
                }
                "configure" -> {
                    val id = call.argument<Number>("id")!!.toInt()
                    try {
                        host.startAppWidgetConfigureActivityForResult(activity, id, 0, REQUEST_RECONFIGURE, null)
                    } catch (_: Exception) {
                    }
                    result.success(null)
                }
                "remove" -> {
                    host.deleteAppWidgetId(call.argument<Number>("id")!!.toInt())
                    result.success(null)
                }
                "scrollable" -> {
                    val view = views[call.argument<Number>("id")!!.toInt()]
                    result.success(view != null && scrolls(view))
                }
                "info" -> {
                    val info = manager.getAppWidgetInfo(call.argument<Number>("id")!!.toInt())
                    result.success(info?.let { describe(it) })
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("widgets", e.message, null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int) {
        val result = pending
        when (requestCode) {
            REQUEST_BIND -> {
                if (result == null) return
                pending = null
                if (resultCode == Activity.RESULT_OK) {
                    configureOrFinish(pendingId, result)
                } else {
                    host.deleteAppWidgetId(pendingId)
                    result.success(null)
                }
            }
            REQUEST_CONFIGURE -> {
                if (result == null) return
                pending = null
                if (resultCode == Activity.RESULT_OK) {
                    result.success(pendingId)
                } else {
                    host.deleteAppWidgetId(pendingId)
                    result.success(null)
                }
            }
        }
    }

    /** Whether the widget holds a list, grid, stack or scroll view. */
    private fun scrolls(view: View): Boolean {
        if (view is android.widget.AbsListView ||
            view is android.widget.AdapterViewAnimator ||
            view is android.widget.ScrollView ||
            view is android.widget.HorizontalScrollView
        ) {
            return true
        }
        if (view is android.view.ViewGroup) {
            for (i in 0 until view.childCount) {
                if (scrolls(view.getChildAt(i))) return true
            }
        }
        return false
    }

    /** Runs the widget's setup screen if it has one, then hands back the id. */
    private fun configureOrFinish(id: Int, result: MethodChannel.Result) {
        val info = manager.getAppWidgetInfo(id)
        if (info?.configure == null) {
            result.success(id)
            return
        }
        pending = result
        pendingId = id
        try {
            host.startAppWidgetConfigureActivityForResult(activity, id, 0, REQUEST_CONFIGURE, null)
        } catch (_: Exception) {
            pending = null
            result.success(id)
        }
    }

    private fun serial(info: AppWidgetProviderInfo) = users.getSerialNumberForUser(info.profile)

    private fun find(provider: String, user: Long): AppWidgetProviderInfo? {
        val component = ComponentName.unflattenFromString(provider) ?: return null
        val profile = users.getUserForSerialNumber(user) ?: return null
        return manager.getInstalledProvidersForProfile(profile).firstOrNull { it.provider == component }
    }

    private fun describe(info: AppWidgetProviderInfo): Map<String, Any?> {
        val pm = activity.packageManager
        val app = try {
            pm.getApplicationLabel(pm.getApplicationInfo(info.provider.packageName, 0)).toString()
        } catch (_: Exception) {
            info.provider.packageName
        }
        val density = activity.resources.displayMetrics.density
        return mapOf(
            "provider" to info.provider.flattenToString(),
            "user" to serial(info),
            "package" to info.provider.packageName,
            "label" to info.loadLabel(pm),
            "app" to app,
            "minWidth" to (info.minWidth / density).toInt(),
            "minHeight" to (info.minHeight / density).toInt(),
            "configurable" to (info.configure != null),
        )
    }

    private fun providers(): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        for (profile in launcherApps.profiles) {
            for (info in manager.getInstalledProvidersForProfile(profile)) {
                out.add(describe(info))
            }
        }
        return out.sortedWith(compareBy({ (it["app"] as String).lowercase() }, { (it["label"] as String).lowercase() }))
    }

    private fun preview(info: AppWidgetProviderInfo): ByteArray? {
        val d = info.loadPreviewImage(activity, activity.resources.displayMetrics.densityDpi)
            ?: info.loadIcon(activity, activity.resources.displayMetrics.densityDpi)
            ?: return null
        val w = d.intrinsicWidth.coerceIn(1, 600)
        val h = (d.intrinsicHeight * w / d.intrinsicWidth.coerceAtLeast(1)).coerceIn(1, 600)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        d.setBounds(0, 0, w, h)
        d.draw(Canvas(bmp))
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
        bmp.recycle()
        return out.toByteArray()
    }

    companion object {
        const val HOST_ID = 2026
        const val REQUEST_BIND = 4201
        const val REQUEST_CONFIGURE = 4202
        const val REQUEST_RECONFIGURE = 4203
    }
}

/** Draws a bound widget id as a native view inside Flutter. */
class WidgetViewFactory(
    private val activity: Activity,
    private val widgets: CarinoWidgets,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val m = args as Map<*, *>
        val id = (m["id"] as Number).toInt()
        val width = (m["width"] as Number).toFloat()
        val height = (m["height"] as Number).toFloat()
        val info = widgets.manager.getAppWidgetInfo(id)
        val view: View = if (info == null) {
            TextView(activity).apply { text = "This widget is no longer available" }
        } else {
            widgets.host.createView(activity, id, info).apply {
                if (android.os.Build.VERSION.SDK_INT >= 31) {
                    updateAppWidgetSize(Bundle(), listOf(SizeF(width, height)))
                } else {
                    @Suppress("DEPRECATION")
                    updateAppWidgetSize(null, width.toInt(), height.toInt(), width.toInt(), height.toInt())
                }
            }
        }
        widgets.views[id] = view
        return object : PlatformView {
            override fun getView() = view
            override fun dispose() {
                if (widgets.views[id] === view) widgets.views.remove(id)
            }
        }
    }
}
