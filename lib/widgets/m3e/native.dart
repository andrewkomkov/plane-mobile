import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'button_group.dart';
import 'loading_indicator.dart';

/// Bridges to the real `androidx.compose.material3:material3:1.5.0-alpha24`
/// components, rendered by Compose inside an Android platform view.
///
/// Flutter cannot link a Compose artifact directly, so the widgets here surface
/// the genuine library composables through `AndroidView`; the Kotlin host lives
/// in `android/app/src/main/kotlin/.../M3ExpressiveViews.kt`.
///
/// Every widget degrades to the Dart implementation in this directory when the
/// platform view is unavailable — on iOS, in widget tests, and in any headless
/// context. That fallback is not decoration: a platform view is a separate
/// render surface and costs noticeably more than a Flutter widget, so the
/// native path is opted into per call site rather than applied globally.
class M3ENative {
  const M3ENative._();

  /// Whether the Compose-backed views can be used at all.
  ///
  /// `Platform.isAndroid` throws on web, so the web check comes first.
  static bool get isAvailable {
    if (kIsWeb) return false;
    // Widget tests run on the host VM with no platform view registry.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    return Platform.isAndroid;
  }
}

/// Theme roles handed to the Compose side so its `ColorScheme` matches the app.
Map<String, dynamic> _themeArgs(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  int argb(Color c) => c.toARGB32();
  return <String, dynamic>{
    'primary': argb(scheme.primary),
    'onPrimary': argb(scheme.onPrimary),
    // Selected button-group items fill with primaryContainer. Sending only
    // `primary` made the Compose group render a different colour from the Dart
    // one for the same state.
    'primaryContainer': argb(scheme.primaryContainer),
    'onPrimaryContainer': argb(scheme.onPrimaryContainer),
    'surfaceContainer': argb(scheme.surfaceContainer),
    'onSurface': argb(scheme.onSurface),
    'onSurfaceVariant': argb(scheme.onSurfaceVariant),
    'isDark': Theme.of(context).brightness == Brightness.dark,
  };
}

/// The library's own `ButtonGroup`, including its native press-expansion
/// behaviour, driven by Compose's `animateWidth` modifier.
///
/// Falls back to [M3EButtonGroup] off Android.
class M3ENativeButtonGroup extends StatefulWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;

  const M3ENativeButtonGroup({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 48,
  });

  @override
  State<M3ENativeButtonGroup> createState() => _M3ENativeButtonGroupState();
}

class _M3ENativeButtonGroupState extends State<M3ENativeButtonGroup> {
  MethodChannel? _channel;

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('plane/m3e/button_group/$id')
      ..setMethodCallHandler((call) async {
        if (call.method == 'onSelected') {
          widget.onSelected(call.arguments as int);
        }
        return null;
      });
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!M3ENative.isAvailable) {
      return M3EButtonGroup(
        height: widget.height,
        items: [
          for (final label in widget.labels) M3EButtonGroupItem(label: label),
        ],
        selectedIndex: widget.selectedIndex,
        onSelected: widget.onSelected,
      );
    }

    return SizedBox(
      height: widget.height,
      child: AndroidView(
        viewType: 'plane/m3e/button_group',
        creationParams: <String, dynamic>{
          'labels': widget.labels,
          'selectedIndex': widget.selectedIndex,
          ..._themeArgs(context),
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      ),
    );
  }
}

/// The library's own shape-morphing `LoadingIndicator`.
///
/// Falls back to [M3ELoadingIndicator] off Android.
class M3ENativeLoadingIndicator extends StatelessWidget {
  final double size;

  const M3ENativeLoadingIndicator({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    if (!M3ENative.isAvailable) {
      return M3ELoadingIndicator(size: size);
    }

    return SizedBox(
      width: size,
      height: size,
      child: AndroidView(
        viewType: 'plane/m3e/loading_indicator',
        creationParams: <String, dynamic>{
          'size': size,
          ..._themeArgs(context),
        },
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
