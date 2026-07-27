@file:OptIn(ExperimentalMaterial3ExpressiveApi::class)

package com.slimshaggy.plane_mobile

import android.content.Context
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
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import android.graphics.Color as AndroidColor

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
 * fit. Every item here is weighted, so the group always divides the width it is
 * given and the overflow path is never taken — this draws nothing.
 *
 * It has to stay that way. An indicator that measures to zero is fine only
 * while overflow is unreachable: the overflow branch in 1.5.0-alpha24 measures
 * the remaining width as `remaining + indicatorWidth`, which goes negative and
 * throws. Dropping the weights would make this reachable again.
 *
 * This is a named composable rather than an inline `{}` on purpose: an empty
 * composable lambda literal trips a codegen crash in the Kotlin 2.1 compiler
 * when it lowers the ComposableSingletons holder to an invokedynamic lambda.
 */
@Composable
@Suppress("EmptyFunctionBlock")
private fun NoOverflow(@Suppress("UNUSED_PARAMETER") state: ButtonGroupMenuState) {
    // Deliberately empty — see the note above. detekt cannot tell this from an
    // oversight, so it is suppressed rather than filled with a no-op.
}

/**
 * Everything a toggle button spends on width that is not the label itself —
 * content padding either side. Only the ratio between items matters here, so
 * this needs to be about right rather than exact.
 */
private val ToggleButtonChrome = 48.dp

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
private class ButtonGroupView(context: Context, id: Int, args: Map<*, *>, messenger: BinaryMessenger) : PlatformView {

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
            val measurer = rememberTextMeasurer()
            val labelStyle = MaterialTheme.typography.labelLarge
            val density = LocalDensity.current

            // Weights are the width each button would take if it sized itself:
            // its measured label plus the button's own padding. ButtonGroup then
            // hands out the width it actually has in those proportions, so the
            // row reads like a content-sized group and still fits exactly.
            //
            // Equal weights would be simpler but wrong at the sizes that matter:
            // "Calendar" is roughly twice "List", so an even split visibly cuts
            // it off on a 360dp screen. Splitting proportionally means the
            // shortfall on a narrow screen is a few pixels spread across four
            // buttons rather than all of it landing on the longest label.
            val weights = remember(labels, labelStyle, density) {
                val chrome = with(density) { ToggleButtonChrome.toPx() }
                labels.map { measurer.measure(it, labelStyle).size.width + chrome }
            }

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
                            // Not optional. `weight` defaults to NaN — size to
                            // content — and content that does not fit takes the
                            // overflow path described on NoOverflow, which
                            // throws out of the measure pass and kills the
                            // process. These four labels stop fitting below
                            // ~411dp of window width: every common phone except
                            // the Pixel 8 this was first checked on, and that
                            // one too once the system font scale goes up.
                            weight = weights[index],
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
private class LoadingIndicatorView(context: Context, args: Map<*, *>) : PlatformView {

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
