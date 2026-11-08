package com.isg32.carino

import android.app.Activity
import android.app.ActivityOptions
import android.app.WallpaperManager
import android.app.role.RoleManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.LauncherActivityInfo
import android.content.pm.LauncherApps
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import android.graphics.Rect
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.Drawable
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.UserHandle
import android.os.UserManager
import android.provider.AlarmClock
import android.provider.CalendarContract
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/**
 * Everything Carino needs from Android as a home app: the app list and its
 * icons, launching, shortcuts, uninstall, default-home status, wallpaper,
 * the notification shade, the torch and system panels.
 *
 * Methods go over `carino/launcher`; events (Home pressed, packages changed,
 * battery, torch) come back over `carino/events` as maps with a `type`.
 */
class LauncherChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methods = MethodChannel(messenger, "carino/launcher")
    private val events = EventChannel(messenger, "carino/events")
    private var sink: EventChannel.EventSink? = null

    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newFixedThreadPool(2)

    private val launcherApps = activity.getSystemService(LauncherApps::class.java)
    private val userManager = activity.getSystemService(UserManager::class.java)
    private val camera = activity.getSystemService(CameraManager::class.java)

    private var pendingPick: MethodChannel.Result? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var torchOn = false

    private val media = CarinoMedia(activity) { emit(it) }

    // Battery updates arrive often; listen only while Cariño is on screen.
    private var resumed = false
    private var batteryRegistered = false

    fun dispose() {
        CarinoNotifications.onChange = null
        media.stop()
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        launcherApps.unregisterCallback(packageCallback)
        try {
            camera.unregisterTorchCallback(torchCallback)
        } catch (_: Exception) {
        }
        stopBattery()
        worker.shutdown()
    }

    fun onHomePressed() = emit(mapOf("type" to "home"))

    fun onResume() {
        resumed = true
        startBattery()
        media.start()
        emit(
            mapOf(
                "type" to "resume",
                "defaultHome" to isDefaultHome(),
                "notificationAccess" to CarinoNotifications.hasAccess(activity),
                "lockAccess" to CarinoLock.isOn(activity),
            ),
        )
    }

    fun onPause() {
        resumed = false
        stopBattery()
        media.stop()
    }

    private fun startBattery() {
        if (sink == null || !resumed || batteryRegistered) return
        batteryRegistered = true
        activity.registerReceiver(batteryReceiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            ?.let { batteryReceiver.onReceive(activity, it) }
    }

    private fun stopBattery() {
        if (!batteryRegistered) return
        batteryRegistered = false
        try {
            activity.unregisterReceiver(batteryReceiver)
        } catch (_: Exception) {
        }
    }

    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_PERMISSION) return
        val result = pendingPermission ?: return
        pendingPermission = null
        result.success(grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED })
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            REQUEST_PICK_IMAGE -> {
                val result = pendingPick ?: return
                pendingPick = null
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) {
                    result.success(null)
                    return
                }
                worker.execute {
                    val path = try {
                        copyToWallpapers(uri)
                    } catch (e: Exception) {
                        null
                    }
                    main.post { result.success(path) }
                }
            }
            REQUEST_HOME_ROLE -> emit(mapOf("type" to "resume", "defaultHome" to isDefaultHome()))
        }
    }

    // region Events

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        startBattery()
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        stopBattery()
    }

    private fun emit(event: Map<String, Any?>) {
        main.post { sink?.success(event) }
    }

    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
            val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
            val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL
            if (level >= 0 && scale > 0) {
                emit(mapOf("type" to "battery", "level" to level * 100 / scale, "charging" to charging))
            }
        }
    }

    private val packageCallback = object : LauncherApps.Callback() {
        private fun changed() = emit(mapOf("type" to "packages"))
        override fun onPackageRemoved(packageName: String?, user: UserHandle?) = changed()
        override fun onPackageAdded(packageName: String?, user: UserHandle?) = changed()
        override fun onPackageChanged(packageName: String?, user: UserHandle?) = changed()
        override fun onPackagesAvailable(packageNames: Array<out String>?, user: UserHandle?, replacing: Boolean) = changed()
        override fun onPackagesUnavailable(packageNames: Array<out String>?, user: UserHandle?, replacing: Boolean) = changed()
    }

    private val torchCallback = object : CameraManager.TorchCallback() {
        override fun onTorchModeChanged(cameraId: String, enabled: Boolean) {
            torchOn = enabled
            emit(mapOf("type" to "torch", "on" to enabled))
        }
    }

    // endregion

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "apps" -> worker.execute {
                    val list = listApps()
                    main.post { result.success(list) }
                }
                "icon" -> {
                    val key = call.argument<String>("key")!!
                    val size = call.argument<Int>("size") ?: 144
                    val mono = call.argument<Boolean>("mono") ?: false
                    worker.execute {
                        val bytes = try {
                            cachedIcon(key, size, mono)
                        } catch (e: Exception) {
                            null
                        }
                        main.post { result.success(bytes) }
                    }
                }
                "launch" -> {
                    val info = findActivity(call.argument<String>("key")!!)
                    if (info == null) {
                        result.success(false)
                        return
                    }
                    val bounds = call.argument<List<Int>>("bounds")?.let { Rect(it[0], it[1], it[2], it[3]) }
                    launcherApps.startMainActivity(info.componentName, info.user, bounds, slideIn())
                    result.success(true)
                }
                "appInfo" -> {
                    findActivity(call.argument<String>("key")!!)?.let {
                        launcherApps.startAppDetailsActivity(it.componentName, it.user, null, null)
                    }
                    result.success(null)
                }
                "uninstall" -> {
                    val pkg = call.argument<String>("package")!!
                    val intent = Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(intent)
                    result.success(null)
                }
                "isSystemApp" -> {
                    val pkg = call.argument<String>("package")!!
                    val flags = activity.packageManager.getApplicationInfo(pkg, 0).flags
                    result.success(flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM != 0)
                }
                "shortcuts" -> result.success(shortcuts(call.argument<String>("key")!!))
                "startShortcut" -> {
                    val info = findActivity(call.argument<String>("key")!!)
                    if (info != null) {
                        launcherApps.startShortcut(
                            info.componentName.packageName,
                            call.argument<String>("id")!!,
                            null,
                            slideIn(),
                            info.user,
                        )
                    }
                    result.success(null)
                }
                "isDefaultHome" -> result.success(isDefaultHome())
                "requestDefaultHome" -> {
                    requestDefaultHome()
                    result.success(null)
                }
                "expandNotifications" -> {
                    expandNotifications()
                    result.success(null)
                }
                "pickImage" -> {
                    pendingPick?.success(null)
                    pendingPick = result
                    val intent = if (Build.VERSION.SDK_INT >= 33) {
                        Intent(MediaStore.ACTION_PICK_IMAGES)
                    } else {
                        Intent(Intent.ACTION_GET_CONTENT).setType("image/*")
                    }
                    activity.startActivityForResult(intent, REQUEST_PICK_IMAGE)
                }
                "setSystemWallpaper" -> {
                    val path = call.argument<String>("path")
                    val bytes = call.argument<ByteArray>("bytes")
                    val which = when (call.argument<String>("which")) {
                        "home" -> WallpaperManager.FLAG_SYSTEM
                        "lock" -> WallpaperManager.FLAG_LOCK
                        else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                    }
                    worker.execute {
                        val ok = try {
                            val input = if (bytes != null) bytes.inputStream() else File(path!!).inputStream()
                            input.use {
                                WallpaperManager.getInstance(activity).setStream(it, null, true, which)
                            }
                            true
                        } catch (e: Exception) {
                            false
                        }
                        main.post { result.success(ok) }
                    }
                }
                "torch" -> {
                    val on = call.argument<Boolean>("on") ?: !torchOn
                    val id = camera.cameraIdList.firstOrNull {
                        camera.getCameraCharacteristics(it).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                    }
                    if (id != null) camera.setTorchMode(id, on)
                    result.success(id != null)
                }
                "torchState" -> result.success(torchOn)
                "dots" -> result.success(CarinoNotifications.counts)
                "media" -> result.success(media.snapshot())
                "mediaAction" -> {
                    media.action(call.argument<String>("action")!!, call.argument<Number>("position")?.toLong())
                    result.success(null)
                }
                "mediaOpen" -> {
                    media.open()
                    result.success(null)
                }
                "hasPermission" -> result.success(granted(permissionFor(call.argument<String>("name")!!)))
                "requestPermission" -> {
                    val permission = permissionFor(call.argument<String>("name")!!)
                    if (granted(permission)) {
                        result.success(true)
                    } else {
                        pendingPermission?.success(false)
                        pendingPermission = result
                        activity.requestPermissions(arrayOf(permission), REQUEST_PERMISSION)
                    }
                }
                "lastLocation" -> result.success(lastLocation())
                "upNext" -> worker.execute {
                    val events = try {
                        todaysEvents()
                    } catch (_: Exception) {
                        emptyList()
                    }
                    val alarm = activity.getSystemService(android.app.AlarmManager::class.java)
                        .nextAlarmClock?.triggerTime
                    main.post { result.success(mapOf("events" to events, "alarm" to alarm)) }
                }
                "nextEvent" -> worker.execute {
                    val event = try {
                        nextEvent()
                    } catch (_: Exception) {
                        null
                    }
                    main.post { result.success(event) }
                }
                "searchContacts" -> {
                    val query = call.argument<String>("query")!!
                    worker.execute {
                        val found = try {
                            searchContacts(query)
                        } catch (_: Exception) {
                            emptyList()
                        }
                        main.post { result.success(found) }
                    }
                }
                "openContact" -> {
                    val uri = ContactsContract.Contacts.getLookupUri(
                        call.argument<Number>("id")!!.toLong(),
                        call.argument<String>("lookup")!!,
                    )
                    activity.startActivity(Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
                "openSetting" -> {
                    try {
                        activity.startActivity(
                            Intent(call.argument<String>("action")!!).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "lockScreen" -> result.success(CarinoLock.lock())
                "hasLockAccess" -> result.success(CarinoLock.isOn(activity))
                "requestLockAccess" -> {
                    activity.startActivity(
                        Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }
                "hasNotificationAccess" -> result.success(CarinoNotifications.hasAccess(activity))
                "requestNotificationAccess" -> {
                    val component = ComponentName(activity, CarinoNotifications::class.java)
                    val intent = if (Build.VERSION.SDK_INT >= 30) {
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                            .putExtra(
                                Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                                component.flattenToString(),
                            )
                    } else {
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    }
                    activity.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
                "battery" -> {
                    val intent = activity.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                    if (intent == null) {
                        result.success(null)
                    } else {
                        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
                        val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                        result.success(
                            mapOf(
                                "level" to if (scale > 0) level * 100 / scale else level,
                                "charging" to (status == BatteryManager.BATTERY_STATUS_CHARGING ||
                                    status == BatteryManager.BATTERY_STATUS_FULL),
                            ),
                        )
                    }
                }
                "panel" -> {
                    openPanel(call.argument<String>("name")!!)
                    result.success(null)
                }
                "openIntent" -> {
                    openNamedIntent(call.argument<String>("name")!!)
                    result.success(null)
                }
                "webSearch" -> {
                    val q = call.argument<String>("query")!!
                    val url = call.argument<String>("url")
                    val intent = if (url != null) {
                        Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    } else {
                        Intent(Intent.ACTION_WEB_SEARCH).putExtra("query", q)
                    }
                    activity.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("carino", e.message, null)
        }
    }

    // region Apps

    private fun profiles(): List<UserHandle> = launcherApps.profiles

    private fun keyOf(info: LauncherActivityInfo): String =
        "${info.componentName.flattenToString()}#${userManager.getSerialNumberForUser(info.user)}"

    private fun findActivity(key: String): LauncherActivityInfo? {
        val hash = key.lastIndexOf('#')
        if (hash < 0) return null
        val component = ComponentName.unflattenFromString(key.substring(0, hash)) ?: return null
        val serial = key.substring(hash + 1).toLongOrNull() ?: return null
        val user = userManager.getUserForSerialNumber(serial) ?: return null
        return launcherApps.getActivityList(component.packageName, user)
            .firstOrNull { it.componentName == component }
    }

    private fun listApps(): List<Map<String, Any?>> {
        val me = Process.myUserHandle()
        val out = mutableListOf<Map<String, Any?>>()
        for (user in profiles()) {
            val work = user != me
            val paused = work && try {
                userManager.isQuietModeEnabled(user)
            } catch (_: Exception) {
                false
            }
            for (info in launcherApps.getActivityList(null, user)) {
                if (info.componentName.packageName == activity.packageName) continue
                val installed = try {
                    activity.packageManager.getPackageInfo(info.componentName.packageName, 0).firstInstallTime
                } catch (_: PackageManager.NameNotFoundException) {
                    0L
                }
                out.add(
                    mapOf(
                        "key" to keyOf(info),
                        "package" to info.componentName.packageName,
                        "label" to info.label.toString(),
                        "installed" to installed,
                        "work" to work,
                        "paused" to paused,
                    ),
                )
            }
        }
        return out
    }

    private fun renderIcon(info: LauncherActivityInfo, size: Int, mono: Boolean): ByteArray? {
        val d: Drawable = info.getIcon(activity.resources.displayMetrics.densityDpi)
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        // Adaptive layers are 108 dp with the middle 72 dp visible: draw them
        // a quarter larger on each side so the visible part fills the bitmap.
        val pad = size / 4
        if (mono) {
            if (Build.VERSION.SDK_INT < 33 || d !is AdaptiveIconDrawable) return null
            val m = d.monochrome?.mutate() ?: return null
            m.colorFilter = PorterDuffColorFilter(Color.WHITE, PorterDuff.Mode.SRC_IN)
            m.setBounds(-pad, -pad, size + pad, size + pad)
            m.draw(canvas)
        } else if (d is AdaptiveIconDrawable) {
            val circle = Path().apply { addCircle(size / 2f, size / 2f, size / 2f, Path.Direction.CW) }
            canvas.clipPath(circle)
            d.background?.let {
                it.setBounds(-pad, -pad, size + pad, size + pad)
                it.draw(canvas)
            }
            d.foreground?.let {
                it.setBounds(-pad, -pad, size + pad, size + pad)
                it.draw(canvas)
            }
        } else {
            d.setBounds(0, 0, size, size)
            d.draw(canvas)
        }
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
        bmp.recycle()
        return out.toByteArray()
    }

    /**
     * Rendered icons are kept on disk, keyed by the app's last update, so
     * after a reboot Cariño reads files instead of drawing every icon again.
     * A `.none` file records "this app has no monochrome icon".
     */
    private fun cachedIcon(key: String, size: Int, mono: Boolean): ByteArray? {
        val info = findActivity(key) ?: return null
        val updated = try {
            activity.packageManager.getPackageInfo(info.componentName.packageName, 0).lastUpdateTime
        } catch (_: PackageManager.NameNotFoundException) {
            0L
        }
        val dir = File(activity.cacheDir, "icons").apply { mkdirs() }
        val name = "${Integer.toHexString(key.hashCode())}-$size-${if (mono) "m" else "c"}-$updated"
        val png = File(dir, "$name.png")
        val none = File(dir, "$name.none")
        if (png.exists()) return png.readBytes()
        if (none.exists()) return null
        val bytes = renderIcon(info, size, mono)
        try {
            if (bytes != null) png.writeBytes(bytes) else none.createNewFile()
        } catch (_: Exception) {
        }
        return bytes
    }

    private fun shortcuts(key: String): List<Map<String, Any?>> {
        if (!launcherApps.hasShortcutHostPermission()) return emptyList()
        val info = findActivity(key) ?: return emptyList()
        val query = LauncherApps.ShortcutQuery()
            .setPackage(info.componentName.packageName)
            .setActivity(info.componentName)
            .setQueryFlags(
                LauncherApps.ShortcutQuery.FLAG_MATCH_DYNAMIC or
                    LauncherApps.ShortcutQuery.FLAG_MATCH_MANIFEST,
            )
        val list: List<ShortcutInfo> = try {
            launcherApps.getShortcuts(query, info.user) ?: emptyList()
        } catch (_: Exception) {
            emptyList()
        }
        return list.filter { it.isEnabled }
            .sortedBy { it.rank }
            .take(4)
            .map { mapOf("id" to it.id, "label" to (it.shortLabel ?: it.longLabel ?: "").toString()) }
    }

    // endregion

    // region Calendar and contacts

    private fun permissionFor(name: String) = when (name) {
        "calendar" -> android.Manifest.permission.READ_CALENDAR
        "contacts" -> android.Manifest.permission.READ_CONTACTS
        "location" -> android.Manifest.permission.ACCESS_COARSE_LOCATION
        else -> throw IllegalArgumentException(name)
    }

    private fun granted(permission: String) =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    /** The next timed event that hasn't ended, today or tomorrow. */
    private fun nextEvent(): Map<String, Any?>? {
        if (!granted(android.Manifest.permission.READ_CALENDAR)) return null
        val now = System.currentTimeMillis()
        val until = now + 36L * 60 * 60 * 1000
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, now)
            ContentUris.appendId(it, until)
        }.build()
        activity.contentResolver.query(
            uri,
            arrayOf(
                CalendarContract.Instances.TITLE,
                CalendarContract.Instances.BEGIN,
                CalendarContract.Instances.END,
                CalendarContract.Instances.ALL_DAY,
            ),
            "${CalendarContract.Instances.END} > ? AND ${CalendarContract.Instances.ALL_DAY} = 0 " +
                "AND ${CalendarContract.Instances.VISIBLE} = 1",
            arrayOf(now.toString()),
            "${CalendarContract.Instances.BEGIN} ASC",
        )?.use { c ->
            if (!c.moveToFirst()) return null
            return mapOf(
                "title" to (c.getString(0) ?: ""),
                "begin" to c.getLong(1),
                "end" to c.getLong(2),
            )
        }
        return null
    }

    /**
     * The phone's last known approximate place, from whatever already asked
     * for one. Never turns on GPS or waits for a fix.
     */
    private fun lastLocation(): Map<String, Double>? {
        if (!granted(android.Manifest.permission.ACCESS_COARSE_LOCATION)) return null
        val lm = activity.getSystemService(android.location.LocationManager::class.java)
        val best = lm.getProviders(true)
            .mapNotNull {
                try {
                    lm.getLastKnownLocation(it)
                } catch (_: SecurityException) {
                    null
                }
            }
            .maxByOrNull { it.time } ?: return null
        return mapOf("lat" to best.latitude, "lon" to best.longitude)
    }

    /** What's left of today: events that haven't ended, all-day ones first. */
    private fun todaysEvents(): List<Map<String, Any?>> {
        if (!granted(android.Manifest.permission.READ_CALENDAR)) return emptyList()
        val now = System.currentTimeMillis()
        val endOfDay = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 23)
            set(java.util.Calendar.MINUTE, 59)
            set(java.util.Calendar.SECOND, 59)
        }.timeInMillis
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, now)
            ContentUris.appendId(it, endOfDay)
        }.build()
        val out = mutableListOf<Map<String, Any?>>()
        activity.contentResolver.query(
            uri,
            arrayOf(
                CalendarContract.Instances.TITLE,
                CalendarContract.Instances.BEGIN,
                CalendarContract.Instances.END,
                CalendarContract.Instances.ALL_DAY,
                CalendarContract.Instances.EVENT_LOCATION,
            ),
            "${CalendarContract.Instances.END} > ? AND ${CalendarContract.Instances.VISIBLE} = 1",
            arrayOf(now.toString()),
            "${CalendarContract.Instances.ALL_DAY} DESC, ${CalendarContract.Instances.BEGIN} ASC",
        )?.use { c ->
            while (c.moveToNext() && out.size < 4) {
                out.add(
                    mapOf(
                        "title" to (c.getString(0) ?: ""),
                        "begin" to c.getLong(1),
                        "end" to c.getLong(2),
                        "allDay" to (c.getInt(3) == 1),
                        "location" to (c.getString(4) ?: ""),
                    ),
                )
            }
        }
        return out
    }

    private fun searchContacts(query: String): List<Map<String, Any?>> {
        if (query.isBlank() || !granted(android.Manifest.permission.READ_CONTACTS)) return emptyList()
        val uri = Uri.withAppendedPath(ContactsContract.Contacts.CONTENT_FILTER_URI, Uri.encode(query))
        val out = mutableListOf<Map<String, Any?>>()
        activity.contentResolver.query(
            uri,
            arrayOf(
                ContactsContract.Contacts._ID,
                ContactsContract.Contacts.LOOKUP_KEY,
                ContactsContract.Contacts.DISPLAY_NAME_PRIMARY,
            ),
            null,
            null,
            null,
        )?.use { c ->
            while (c.moveToNext() && out.size < 4) {
                out.add(mapOf("id" to c.getLong(0), "lookup" to c.getString(1), "name" to (c.getString(2) ?: "")))
            }
        }
        return out
    }

    // endregion

    // region System

    /**
     * Cariño has one page, so the system wallpaper should be exactly the
     * screen. Launchers with several pages ask for a much wider one, which
     * Android then stretches and pans in Recents and app transitions.
     */
    private fun fitWallpaperToScreen() {
        try {
            val (w, h) = if (Build.VERSION.SDK_INT >= 30) {
                val bounds = activity.windowManager.maximumWindowMetrics.bounds
                bounds.width() to bounds.height()
            } else {
                val m = android.util.DisplayMetrics()
                @Suppress("DEPRECATION")
                activity.windowManager.defaultDisplay.getRealMetrics(m)
                m.widthPixels to m.heightPixels
            }
            WallpaperManager.getInstance(activity).suggestDesiredDimensions(w, h)
        } catch (_: Exception) {
        }
    }

    /** Apps Cariño opens slide in from the right over it. */
    private fun slideIn() = ActivityOptions.makeCustomAnimation(
        activity,
        R.anim.carino_app_enter,
        R.anim.carino_stay,
    ).toBundle()

    private fun isDefaultHome(): Boolean {
        // The role holder is the authoritative answer on Android 10+.
        if (Build.VERSION.SDK_INT >= 29) {
            val roles = activity.getSystemService(RoleManager::class.java)
            if (roles.isRoleAvailable(RoleManager.ROLE_HOME)) {
                return roles.isRoleHeld(RoleManager.ROLE_HOME)
            }
        }
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val res = activity.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        return res?.activityInfo?.packageName == activity.packageName
    }

    private fun requestDefaultHome() {
        if (Build.VERSION.SDK_INT >= 29) {
            val roles = activity.getSystemService(RoleManager::class.java)
            if (roles.isRoleAvailable(RoleManager.ROLE_HOME) && !roles.isRoleHeld(RoleManager.ROLE_HOME)) {
                activity.startActivityForResult(roles.createRequestRoleIntent(RoleManager.ROLE_HOME), REQUEST_HOME_ROLE)
                return
            }
        }
        activity.startActivity(Intent(Settings.ACTION_HOME_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    @Suppress("WrongConstant")
    private fun expandNotifications() {
        try {
            val service = activity.getSystemService("statusbar")
            val manager = Class.forName("android.app.StatusBarManager")
            manager.getMethod("expandNotificationsPanel").invoke(service)
        } catch (_: Exception) {
        }
    }

    private fun openPanel(name: String) {
        val action = if (Build.VERSION.SDK_INT >= 29) {
            when (name) {
                "wifi" -> Settings.Panel.ACTION_WIFI
                "internet" -> Settings.Panel.ACTION_INTERNET_CONNECTIVITY
                "volume" -> Settings.Panel.ACTION_VOLUME
                "nfc" -> Settings.Panel.ACTION_NFC
                "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
                "dnd" -> Settings.ACTION_ZEN_MODE_PRIORITY_SETTINGS
                else -> Settings.ACTION_SETTINGS
            }
        } else {
            when (name) {
                "wifi", "internet" -> Settings.ACTION_WIFI_SETTINGS
                "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
                "volume" -> Settings.ACTION_SOUND_SETTINGS
                "nfc" -> Settings.ACTION_NFC_SETTINGS
                else -> Settings.ACTION_SETTINGS
            }
        }
        activity.startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun openNamedIntent(name: String) {
        val intent = when (name) {
            "clock" -> Intent(AlarmClock.ACTION_SHOW_ALARMS)
            "timer" -> Intent(AlarmClock.ACTION_SHOW_TIMERS)
            "alarm" -> Intent(AlarmClock.ACTION_SET_ALARM)
            "calendar" -> Intent(Intent.ACTION_VIEW, Uri.parse("content://com.android.calendar/time/${System.currentTimeMillis()}"))
            "camera" -> Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)
            "settings" -> Intent(Settings.ACTION_SETTINGS)
            "homeSettings" -> Intent(Settings.ACTION_HOME_SETTINGS)
            else -> return
        }
        try {
            activity.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: Exception) {
        }
    }

    private fun copyToWallpapers(uri: Uri): String {
        val dir = File(activity.filesDir, "wallpapers").apply { mkdirs() }
        val file = File(dir, "photo-${System.currentTimeMillis()}.img")
        activity.contentResolver.openInputStream(uri).use { input ->
            file.outputStream().use { output -> input!!.copyTo(output) }
        }
        return file.absolutePath
    }

    // endregion

    // Registered last: the callbacks above must exist first.
    init {
        fitWallpaperToScreen()
        CarinoNotifications.onChange = { counts ->
            emit(mapOf("type" to "dots", "counts" to counts))
        }
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
        launcherApps.registerCallback(packageCallback, main)
        try {
            camera.registerTorchCallback(torchCallback, main)
        } catch (_: Exception) {
        }
    }

    companion object {
        private const val REQUEST_PICK_IMAGE = 4101
        private const val REQUEST_HOME_ROLE = 4102
        private const val REQUEST_PERMISSION = 4103
    }
}
