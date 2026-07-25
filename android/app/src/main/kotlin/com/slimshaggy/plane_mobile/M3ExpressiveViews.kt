@file:OptIn(ExperimentalMaterial3ExpressiveApi::class)

package com.slimshaggy.plane_mobile

import android.content.Context
import android.graphics.Color as AndroidColor
import android.view.View
import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.ButtonGroup
import androidx.compose.material3.ButtonGroupMenuState
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.LoadingIndicator
import androidx.compose.material3.MaterialExpressiveTheme
import androidx.compose.material3.MotionScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.unit.dp
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Hosts genuine Material 3 Expressive components from
 * `androidx.compose.material3:material3:1.5.0-alpha24`.
 *
 * These are the real Compose composables — `ButtonGroup`, `ToggleButton`,
 * `LoadingIndicator` — not reimplementations. Flutter cannot call Compose
 * directly, so each one is rendered into a [ComposeView] surfaced to Dart as an
 * Android platform view.
 *
 * Cost of doing it this way, so it is chosen deliberately per call site rather
 * than everywhere: a platform view is a separate render surface composited into
 * the Flutter scene, which is materially more expensive than a Flutter widget
 * and is Android-only. Dart equivalents in `lib/widgets/m3e/` back every one of
 * these on iOS and in tests.
 */

private const val CHANNEL_PREFIX = "plane/m3e"

/** Colours are passed from Dart so the Compose tree matches the app's theme. */
private data class HostColors(
    val primary: Color,
    val onPrimary: Color,
    val primaryContainer: Color,
    val onPrimaryContainer: Color,
    val surfaceContainer: Color,
    val onSurface: Color,
    val onSurfaceVariant: Color,
    val isDark: Boolean,
) {
    /**
     * A ColorScheme built from the handful of roles Dart sends. Only the roles
     * these components actually read are meaningful; the rest are filled from
     * the same values so nothing renders as Compose's default purple.
     */
    fun toScheme(): ColorScheme = ColorScheme(
        primary = primary,
        onPrimary = onPrimary,
        primaryContainer = primaryContainer,
        onPrimaryContainer = onPrimaryContainer,
        inversePrimary = primary,
        secondary = primary,
        onSecondary = onPrimary,
        secondaryContainer = surfaceContainer,
        onSecondaryContainer = onSurface,
        tertiary = primary,
        onTertiary = onPrimary,
        tertiaryContainer = surfaceContainer,
        onTertiaryContainer = onSurface,
        background = surfaceContainer,
        onBackground = onSurface,
        surface = surfaceContainer,
        onSurface = onSurface,
        surfaceVariant = surfaceContainer,
        onSurfaceVariant = onSurfaceVariant,
        surfaceTint = primary,
        inverseSurface = onSurface,
        inverseOnSurface = surfaceContainer,
        error = Color(0xFFEF4444),
        onError = Color.White,
        errorContainer = Color(0xFFEF4444),
        onErrorContainer = Color.White,
        outline = onSurfaceVariant,
        outlineVariant = onSurfaceVariant.copy(alpha = 0.4f),
        scrim = Color.Black,
        surfaceBright = surfaceContainer,
        surfaceDim = surfaceContainer,
        surfaceContainer = surfaceContainer,
        surfaceContainerHigh = surfaceContainer,
        surfaceContainerHighest = surfaceContainer,
        surfaceContainerLow = surfaceContainer,
        surfaceContainerLowest = surfaceContainer,
    )

    companion object {
        fun from(args: Map<*, *>): HostColors {
            fun color(key: String, fallback: Long): Color {
                val v = (args[key] as? Number)?.toLong() ?: fallback
                return Color(v.toInt())
            }
            return HostColors(
                primary = color("primary", 0xFF5E6AD2),
                onPrimary = color("onPrimary", 0xFFFFFFFF),
                primaryContainer = color("primaryContainer", 0xFF5E6AD2),
                onPrimaryContainer = color("onPrimaryContainer", 0xFFFDFAFF),
                surfaceContainer = color("surfaceContainer", 0xFF201F1F),
                onSurface = color("onSurface", 0xFFE5E2E1),
                onSurfaceVariant = color("onSurfaceVariant", 0xFFC6C5D5),
                isDark = args["isDark"] as? Boolean ?: true,
            )
        }
    }
}

/**
 * ButtonGroup requires an overflow indicator for the case where items do not
 * fit. The groups here are short and fixed, so nothing ever overflows and the
 * indicator draws nothing.
 *
 * This is a named composable rather than an inline `{}` on purpose: an empty
 * composable lambda literal trips a codegen crash in the Kotlin 2.1 compiler
 * when it lowers the ComposableSingletons holder to an invokedynamic lambda.
 */
@Composable
private fun NoOverflow(@Suppress("UNUSED_PARAMETER") state: ButtonGroupMenuState) {
}

@Composable
private fun ExpressiveHost(colors: HostColors, content: @Composable () -> Unit) {
    // MaterialExpressiveTheme is what switches the library into the expressive
    // token set — springy MotionScheme, the wider shape scale, the emphasized
    // type roles. Plain MaterialTheme would give the non-expressive defaults.
    MaterialExpressiveTheme(
        colorScheme = colors.toScheme(),
        motionScheme = MotionScheme.expressive(),
    ) {
        content()
    }
}

/**
 * The real `androidx.compose.material3.ButtonGroup`, including the press
 * interaction where the held button expands and its neighbours give way —
 * driven here by the library's own `animateWidth` modifier.
 */
private class ButtonGroupView(
    context: Context,
    id: Int,
    args: Map<*, *>,
    messenger: BinaryMessenger,
) : PlatformView {

    // These are properties rather than locals in `init` on purpose: the Kotlin
    // 2.1 backend crashes ("No mapping for symbol") when a composable lambda
    // captures a val declared in an init block.
    private val labels: List<String> =
        (args["labels"] as? List<*>)?.map { it.toString() } ?: emptyList()
    private val initialIndex: Int = (args["selectedIndex"] as? Number)?.toInt() ?: 0
    private val colors: HostColors = HostColors.from(args)

    private val channel = MethodChannel(messenger, "$CHANNEL_PREFIX/button_group/$id")
    private val composeView = ComposeView(context)

    init {
        composeView.setBackgroundColor(AndroidColor.TRANSPARENT)
        composeView.setContent { Content() }
    }

    @Composable
    private fun Content() {
        var selected by remember { mutableIntStateOf(initialIndex) }

        ExpressiveHost(colors) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                ButtonGroup(
                    overflowIndicator = { NoOverflow(it) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    labels.forEachIndexed { index, label ->
                        toggleableItem(
                            checked = selected == index,
                            label = label,
                            onCheckedChange = {
                                selected = index
                                channel.invokeMethod("onSelected", index)
                            },
                        )
                    }
                }
            }
        }
    }

    override fun getView(): View = composeView

    override fun dispose() {
        composeView.disposeComposition()
    }
}

/**
 * The real `androidx.compose.material3.LoadingIndicator` — the expressive
 * shape-morphing indicator, animating through the library's own polygon set.
 */
private class LoadingIndicatorView(
    context: Context,
    args: Map<*, *>,
) : PlatformView {

    private val indicatorSize: Float = (args["size"] as? Number)?.toFloat() ?: 48f
    private val colors: HostColors = HostColors.from(args)
    private val composeView = ComposeView(context)

    init {
        composeView.setBackgroundColor(AndroidColor.TRANSPARENT)
        composeView.setContent { Content() }
    }

    @Composable
    private fun Content() {
        ExpressiveHost(colors) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                LoadingIndicator(
                    modifier = Modifier.size(indicatorSize.dp),
                    color = colors.primary,
                )
            }
        }
    }

    override fun getView(): View = composeView

    override fun dispose() {
        composeView.disposeComposition()
    }
}

/**
 * Factory for both view types.
 *
 * The [ComposeView] is attached to the hosting activity's lifecycle, saved-state
 * and ViewModelStore owners. Without those a ComposeView throws as soon as it
 * tries to compose — which is why [MainActivity] extends FlutterFragmentActivity
 * (a ComponentActivity) rather than the default FlutterActivity.
 */
class M3ExpressiveViewFactory(
    private val messenger: BinaryMessenger,
    private val activityProvider: () -> ComponentActivity?,
    private val kind: Kind,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    enum class Kind { BUTTON_GROUP, LOADING_INDICATOR }

    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        val map = args as? Map<*, *> ?: emptyMap<String, Any>()
        val view = when (kind) {
            Kind.BUTTON_GROUP -> ButtonGroupView(context, id, map, messenger)
            Kind.LOADING_INDICATOR -> LoadingIndicatorView(context, map)
        }
        activityProvider()?.let { owner ->
            view.getView()?.apply {
                setViewTreeLifecycleOwner(owner)
                setViewTreeSavedStateRegistryOwner(owner)
                setViewTreeViewModelStoreOwner(owner)
            }
        }
        return view
    }

    companion object {
        const val BUTTON_GROUP_ID = "plane/m3e/button_group"
        const val LOADING_INDICATOR_ID = "plane/m3e/loading_indicator"
    }
}
