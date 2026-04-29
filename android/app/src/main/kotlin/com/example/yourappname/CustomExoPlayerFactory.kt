package com.example.yourappname

import android.content.Context
import android.os.Handler
import androidx.media3.common.util.Util
import androidx.media3.exoplayer.RenderersFactory
import androidx.media3.exoplayer.Renderer
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.video.VideoRendererEventListener

object CustomExoPlayerFactory {

    fun create(context: Context): ExoPlayer {
        // Custom RenderersFactory with software fallback
        val renderersFactory: RenderersFactory = object : DefaultRenderersFactory(context) {
           override fun buildVideoRenderers(
                context: Context,
                extensionRendererMode: Int,
                mediaCodecSelector: MediaCodecSelector,
                enableDecoderFallback: Boolean,
                eventHandler: Handler,
                eventListener: VideoRendererEventListener,
                allowedVideoJoiningTimeMs: Long,
                out: ArrayList<Renderer>
            ) {
                // Force software decoder fallback
                super.buildVideoRenderers(
                    context,
                    extensionRendererMode,
                    mediaCodecSelector,
                    true, // enable fallback
                    eventHandler,
                    eventListener,
                    allowedVideoJoiningTimeMs,
                    out
                )
            }
        }.setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER)

        return ExoPlayer.Builder(context, renderersFactory)
            .setHandleAudioBecomingNoisy(true)
            .setTrackSelector(
                androidx.media3.exoplayer.trackselection.DefaultTrackSelector(context)
                    .apply {
                        setParameters(buildUponParameters().setAllowVideoMixedMimeTypeAdaptiveness(true))
                    }
            )
            .build()
    }
}
