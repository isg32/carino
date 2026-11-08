package com.isg32.carino

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var launcher: LauncherChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launcher = LauncherChannel(this, flutterEngine.dartExecutor.binaryMessenger)
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
    }

    override fun onPause() {
        launcher?.onPause()
        super.onPause()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        launcher?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        launcher?.dispose()
        launcher = null
        super.onDestroy()
    }
}
