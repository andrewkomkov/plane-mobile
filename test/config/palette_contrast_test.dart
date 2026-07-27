import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/config/theme.dart';

/// Relative luminance, WCAG 2.1 formula.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Renders under a given theme and hands back a BuildContext from inside it,
/// which is what the palette resolves against.
Future<BuildContext> _contextFor(WidgetTester tester, ThemeData theme) async {
  late BuildContext captured;
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: Builder(builder: (context) {
      captured = context;
      return const SizedBox();
    }),
  ));
  return captured;
}

void main() {
  // WCAG 1.4.11: a graphical object that carries meaning needs 3:1 against
  // what is behind it. These icons are the only thing saying what state or
  // priority an issue has, so they qualify.
  const minimum = 3.0;

  const priorities = ['urgent', 'high', 'medium', 'low', 'none'];
  const groups = [
    'backlog',
    'unstarted',
    'started',
    'completed',
    'cancelled',
  ];

  group('palette contrast', () {
    for (final entry in {
      'light': PlaneTheme.light(),
      'dark': PlaneTheme.dark(),
    }.entries) {
      testWidgets('${entry.key} theme clears $minimum:1 on its surfaces',
          (tester) async {
        final theme = entry.value;
        final context = await _contextFor(tester, theme);
        final scheme = theme.colorScheme;

        // Both surfaces matter: rows sit on `surface`, the page behind them on
        // the scaffold background, and the same icon is drawn over each.
        final backdrops = <String, Color>{
          'surface': scheme.surface,
          'scaffold': theme.scaffoldBackgroundColor,
        };

        for (final backdrop in backdrops.entries) {
          for (final p in priorities) {
            final ratio =
                _contrast(PlaneTheme.priorityColor(context, p), backdrop.value);
            expect(ratio, greaterThanOrEqualTo(minimum),
                reason: 'priority "$p" on ${entry.key} ${backdrop.key} '
                    'measures ${ratio.toStringAsFixed(2)}:1');
          }
          for (final g in groups) {
            final ratio = _contrast(
                PlaneTheme.stateGroupColor(context, g), backdrop.value);
            expect(ratio, greaterThanOrEqualTo(minimum),
                reason: 'state "$g" on ${entry.key} ${backdrop.key} '
                    'measures ${ratio.toStringAsFixed(2)}:1');
          }
        }
      });
    }

    testWidgets('backlog and unstarted are told apart by shape',
        (tester) async {
      // They sit two greys apart, which is not a difference you can see in a
      // list. The glyph has to carry it.
      expect(PlaneTheme.stateIcon('backlog'),
          isNot(PlaneTheme.stateIcon('unstarted')));
    });

    for (final entry in {
      'light': PlaneTheme.light(),
      'dark': PlaneTheme.dark(),
    }.entries) {
      testWidgets('${entry.key} pending amber reads on its surface and fill',
          (tester) async {
        final theme = entry.value;
        final context = await _contextFor(tester, theme);
        final pending = PlaneTheme.pendingColor(context);

        final onSurface = _contrast(pending, theme.colorScheme.surface);
        expect(onSurface, greaterThanOrEqualTo(minimum),
            reason: 'the sync icon on ${entry.key} surface measures '
                '${onSurface.toStringAsFixed(2)}:1');

        // The badge draws its count on top of the amber, so the pair has to
        // hold up on its own — and which side of the range the amber sits on
        // flips between themes.
        final onFill = _contrast(PlaneTheme.onPendingColor(context), pending);
        expect(onFill, greaterThanOrEqualTo(4.5),
            reason: 'the badge count on ${entry.key} amber measures '
                '${onFill.toStringAsFixed(2)}:1');
      });
    }

    for (final entry in {
      'light': PlaneTheme.light(),
      'dark': PlaneTheme.dark(),
    }.entries) {
      testWidgets('${entry.key} project badges clear the text threshold',
          (tester) async {
        final theme = entry.value;
        final context = await _contextFor(tester, theme);

        // These draw the identifier as text, not as an icon, so 4.5:1 applies
        // rather than 3:1.
        for (var i = 0; i < PlaneTheme.projectBadgeCount; i++) {
          final badge = PlaneTheme.projectBadgeColor(context, i);
          final ratio = _contrast(badge, theme.colorScheme.surfaceContainerLow);
          expect(ratio, greaterThanOrEqualTo(4.5),
              reason: 'badge $i on ${entry.key} measures '
                  '${ratio.toStringAsFixed(2)}:1');
        }
      });
    }

    for (final entry in {
      'light': PlaneTheme.light(),
      'dark': PlaneTheme.dark(),
    }.entries) {
      testWidgets('${entry.key} surface ramp steps down at every level',
          (tester) async {
        final scheme = entry.value.colorScheme;
        // Nothing else separates a card from the page it sits on. When two
        // adjacent steps hold the same value — surface and surfaceContainerLow
        // were both #F8F8F8 in light mode — every filled surface reads as flat
        // and only its outline says where it ends.
        final ramp = <String, Color>{
          'surfaceContainerLowest': scheme.surfaceContainerLowest,
          'surface': scheme.surface,
          'surfaceContainerLow': scheme.surfaceContainerLow,
          'surfaceContainer': scheme.surfaceContainer,
          'surfaceContainerHigh': scheme.surfaceContainerHigh,
          'surfaceContainerHighest': scheme.surfaceContainerHighest,
        };

        final names = ramp.keys.toList();
        for (var i = 0; i < names.length - 1; i++) {
          final here = _luminance(ramp[names[i]]!);
          final next = _luminance(ramp[names[i + 1]]!);
          // Dark themes climb as they go up the ramp, light themes descend.
          final moved = entry.key == 'light' ? here > next : here < next;
          expect(moved, isTrue,
              reason: '${names[i]} and ${names[i + 1]} do not differ on '
                  '${entry.key}');
        }
      });
    }

    testWidgets('every state group has its own glyph', (tester) async {
      final icons = groups.map(PlaneTheme.stateIcon).toSet();
      expect(icons.length, groups.length,
          reason: 'two state groups share an icon');
    });
  });
}
