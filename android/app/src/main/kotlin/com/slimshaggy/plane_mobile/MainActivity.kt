package com.slimshaggy.plane_mobile

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Extends FlutterFragmentActivity rather than the default FlutterActivity so the
 * activity is a ComponentActivity. Compose's [androidx.compose.ui.platform.ComposeView]
 * requires ViewTreeLifecycleOwner / SavedStateRegistryOwner / ViewModelStoreOwner
 * to be present, and plain FlutterActivity provides none of them — the Material 3
 * Expressive platform views would throw on first composition without this.
 */
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val registry = flutterEngine.platformViewsController.registry

        UpdateInstaller.register(messenger, { this }, applicationContext)

        registry.registerViewFactory(
            M3ExpressiveViewFactory.BUTTON_GROUP_ID,
            M3ExpressiveViewFactory(
                messenger,
                { this },
                M3ExpressiveViewFactory.Kind.BUTTON_GROUP,
            ),
        )
        registry.registerViewFactory(
            M3ExpressiveViewFactory.LOADING_INDICATOR_ID,
            M3ExpressiveViewFactory(
                messenger,
                { this },
                M3ExpressiveViewFactory.Kind.LOADING_INDICATOR,
            ),
        )
    }
}
