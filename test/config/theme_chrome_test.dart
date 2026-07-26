import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/config/theme.dart';
import 'package:plane_mobile/widgets/m3e/loading_indicator.dart';

/// WCAG 2.1 contrast, as in `palette_contrast_test.dart`.
double _contrast(Color a, Color b) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('system overlay style', () {
    test('status bar icons contrast with the theme behind them', () {
      // The bug this replaces: a single `Brightness.light` pinned in main(),
      // which on Android means *white* icons — on a #FFFFFF scaffold.
      final light = PlaneTheme.overlayStyle(Brightness.light);
      expect(light.statusBarIconBrightness, Brightness.dark);
      // iOS names the same thing from the other end.
      expect(light.statusBarBrightness, Brightness.light);

      final dark = PlaneTheme.overlayStyle(Brightness.dark);
      expect(dark.statusBarIconBrightness, Brightness.light);
      expect(dark.statusBarBrightness, Brightness.dark);
    });

    test('the app bar theme carries the same style, per theme', () {
      expect(PlaneTheme.light().appBarTheme.systemOverlayStyle
          ?.statusBarIconBrightness, Brightness.dark);
      expect(PlaneTheme.dark().appBarTheme.systemOverlayStyle
          ?.statusBarIconBrightness, Brightness.light);
    });
  });

  group('filledButtonTheme', () {
    test('paints the container role, not the pale primary', () {
      for (final theme in [PlaneTheme.light(), PlaneTheme.dark()]) {
        final style = theme.filledButtonTheme.style!;
        expect(
          style.backgroundColor!.resolve(<WidgetState>{}),
          theme.colorScheme.primaryContainer,
          reason: 'left to M3 the fill resolves to colorScheme.primary, which '
              'in the dark scheme is the pale tone meant to sit *on* a dark '
              'surface',
        );
        expect(
          style.foregroundColor!.resolve(<WidgetState>{}),
          theme.colorScheme.onPrimaryContainer,
        );
      }
    });

    testWidgets('a loading indicator on one is not the colour of the fill',
        (tester) async {
      for (final theme in [PlaneTheme.light(), PlaneTheme.dark()]) {
        late BuildContext insideButton;
        late BuildContext onThePage;

        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(builder: (pageContext) {
              onThePage = pageContext;
              return FilledButton(
                onPressed: () {},
                child: Builder(builder: (buttonContext) {
                  insideButton = buttonContext;
                  return const SizedBox.shrink();
                }),
              );
            }),
          ),
        ));
        // MaterialApp crossfades between themes, so the second pass has to be
        // allowed to arrive before anything is read off it.
        await tester.pumpAndSettle();

        // Whatever the button colours its own icons is what the indicator has
        // to be — anything else is a shape drawn onto the fill it sits on.
        // WCAG 1.4.11 asks 3:1 of a graphic that carries meaning, and "the
        // save is still running" is meaning.
        expect(
          _contrast(
            M3ELoadingIndicator.resolveColor(insideButton),
            theme.colorScheme.primaryContainer,
          ),
          greaterThan(3.0),
          reason: 'in the light scheme primaryContainer *is* primary, so an '
              'indicator left on its default was the fill colour and the '
              'button simply looked empty for the whole of the save',
        );
        expect(
          M3ELoadingIndicator.resolveColor(insideButton),
          IconTheme.of(insideButton).color,
        );
        expect(
          M3ELoadingIndicator.resolveColor(onThePage),
          theme.colorScheme.primary,
          reason: 'a loader that owns an empty screen keeps the accent',
        );
      }
    });
  });

  group('floating surfaces', () {
    test('dialog, sheet and snackbar all carry the hairline', () {
      for (final theme in [PlaneTheme.light(), PlaneTheme.dark()]) {
        final shapes = <String, ShapeBorder?>{
          'dialog': theme.dialogTheme.shape,
          'bottomSheet': theme.bottomSheetTheme.shape,
          'snackBar': theme.snackBarTheme.shape,
        };
        shapes.forEach((name, shape) {
          final side = (shape! as RoundedRectangleBorder).side;
          expect(side.style, BorderStyle.solid,
              reason: '$name floats over arbitrary content in a '
                  'zero-elevation app, so the hairline is its only boundary');
          expect(side.color, theme.colorScheme.outlineVariant, reason: name);
        });
      }
    });
  });

  group('iconTheme', () {
    test('the ambient icon colour is a role, not Material\'s literal', () {
      for (final theme in [PlaneTheme.light(), PlaneTheme.dark()]) {
        expect(theme.iconTheme.color, theme.colorScheme.onSurface);
      }
    });
  });
}
