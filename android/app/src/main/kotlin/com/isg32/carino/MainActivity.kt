package com.isg32.carino

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var launcher: LauncherChannel? = null
    private var widgets: CarinoWidgets? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        // First, so a crash on the Android side is written down and shown
        // on the next launch.
        CrashFiles.installCrashHandler(this)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CrashFiles.register(this, flutterEngine.dartExecutor.binaryMessenger)
        launcher = LauncherChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        val hosted = CarinoWidgets(this, flutterEngine.dartExecutor.binaryMessenger)
        widgets = hosted
        flutterEngine.platformViewsController.registry
            .registerViewFactory("carino/appwidget", WidgetViewFactory(this, hosted))
    }

    /** The Home button while Carino is already in front: back to Home. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == Intent.ACTION_MAIN && intent.hasCategory(Intent.CATEGORY_HOME)) {
            launcher?.onHomePressed()
        }
    }

    override fun onResume() {
        super.onResume()
        launcher?.onResume()
        widgets?.onResume()
    }

    override fun onPause() {
        launcher?.onPause()
        widgets?.onPause()
        super.onPause()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        launcher?.onActivityResult(requestCode, resultCode, data)
        widgets?.onActivityResult(requestCode, resultCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        launcher?.onPermissionResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        launcher?.dispose()
        widgets?.dispose()
        widgets = null
        launcher = null
        super.onDestroy()
    }
}
