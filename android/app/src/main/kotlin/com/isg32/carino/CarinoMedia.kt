package com.isg32.carino

import android.content.ComponentName
import android.content.Context
import android.content.pm.LauncherApps
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.os.SystemClock

/**
 * What's playing, for the Now playing widget: the active media session's
 * track, position and controls. Reading sessions needs notification access
 * (the same as dots). Only listens while Cariño is on screen.
 */
class CarinoMedia(
    private val context: Context,
    private val emit: (Map<String, Any?>) -> Unit,
) {
    private val sessions = context.getSystemService(MediaSessionManager::class.java)
    private val component = ComponentName(context, CarinoNotifications::class.java)
    private val main = Handler(Looper.getMainLooper())
    private var controller: MediaController? = null
    private var listening = false

    /** Every open session, watched so one starting to play is noticed. */
    private var watched: List<MediaController> = emptyList()

    /** Sessions seen playing: only these may show (paused, to resume). */
    private val seenPlaying = mutableSetOf<android.media.session.MediaSession.Token>()

    private val sessionsChanged = MediaSessionManager.OnActiveSessionsChangedListener { list ->
        choose(list ?: emptyList())
    }

    private val callback = object : MediaController.Callback() {
        override fun onPlaybackStateChanged(state: PlaybackState?) = choose(watched)
        override fun onMetadataChanged(metadata: MediaMetadata?) = choose(watched)
        override fun onSessionDestroyed() = refresh()
    }

    fun start() {
        if (listening || !CarinoNotifications.hasAccess(context)) {
            if (!listening) publish()
            return
        }
        try {
            sessions.addOnActiveSessionsChangedListener(sessionsChanged, component, main)
            listening = true
            refresh()
        } catch (_: SecurityException) {
            publish()
        }
    }

    fun stop() {
        if (!listening) return
        listening = false
        try {
            sessions.removeOnActiveSessionsChangedListener(sessionsChanged)
        } catch (_: Exception) {
        }
        for (c in watched) c.unregisterCallback(callback)
        watched = emptyList()
        controller = null
    }

    private fun refresh() {
        val list = try {
            sessions.getActiveSessions(component)
        } catch (_: SecurityException) {
            emptyList()
        }
        choose(list)
    }

    /**
     * Shows a session only once it has been seen playing: one playing now
     * first, else the last one that was playing and is now paused (so it can
     * be resumed). Sessions apps leave open without playing anything never
     * show; then the widget says nothing is playing.
     */
    private fun choose(list: List<MediaController>) {
        if (list.map { it.sessionToken } != watched.map { it.sessionToken }) {
            for (c in watched) c.unregisterCallback(callback)
            for (c in list) c.registerCallback(callback, main)
            watched = list
        }
        val real = list.filter { !it.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE).isNullOrBlank() }
        val playing = real.filter { it.playbackState?.state == PlaybackState.STATE_PLAYING }
        playing.forEach { seenPlaying.add(it.sessionToken) }
        seenPlaying.retainAll(list.map { it.sessionToken }.toSet())
        controller = playing.firstOrNull()
            ?: real.firstOrNull { it.sessionToken in seenPlaying }
        publish()
    }

    fun snapshot(): Map<String, Any?>? {
        val c = controller ?: return null
        val meta = c.metadata
        val state = c.playbackState
        // The app's name as the launcher knows it (apps without an icon
        // aren't visible to Cariño, so they get no name).
        val app = try {
            context.getSystemService(LauncherApps::class.java)
                .getActivityList(c.packageName, android.os.Process.myUserHandle())
                .firstOrNull()?.label?.toString() ?: ""
        } catch (_: Exception) {
            ""
        }
        // Where playback is right now, from the last reported position.
        var position = state?.position ?: 0L
        if (state != null && state.state == PlaybackState.STATE_PLAYING && state.lastPositionUpdateTime > 0) {
            position += ((SystemClock.elapsedRealtime() - state.lastPositionUpdateTime) * state.playbackSpeed).toLong()
        }
        return mapOf(
            "package" to c.packageName,
            "app" to app,
            "title" to (meta?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: ""),
            "artist" to (
                meta?.getString(MediaMetadata.METADATA_KEY_ARTIST)
                    ?: meta?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
                    ?: ""
                ),
            "duration" to (meta?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L),
            "position" to position.coerceAtLeast(0L),
            "playing" to (state?.state == PlaybackState.STATE_PLAYING),
            "canSeek" to ((state?.actions ?: 0L) and PlaybackState.ACTION_SEEK_TO != 0L),
        )
    }

    private fun publish() {
        emit(mapOf("type" to "media", "media" to snapshot()))
    }

    fun action(name: String, position: Long?) {
        val t = controller?.transportControls ?: return
        when (name) {
            "play" -> t.play()
            "pause" -> t.pause()
            "next" -> t.skipToNext()
            "previous" -> t.skipToPrevious()
            "seek" -> if (position != null) t.seekTo(position)
        }
    }

    /** Opens the app that is playing. */
    fun open() {
        val c = controller ?: return
        c.sessionActivity?.let {
            try {
                it.send()
                return
            } catch (_: Exception) {
            }
        }
        context.packageManager.getLaunchIntentForPackage(c.packageName)?.let {
            context.startActivity(it.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }
}
