import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/utils/time_ago.dart';

void main() {
  group('timeAgo', () {
    test('returns "just now" for less than a minute ago', () {
      final dt = DateTime.now().subtract(const Duration(seconds: 30));
      expect(timeAgo(dt), 'just now');
    });

    test('returns minutes ago', () {
      final dt = DateTime.now().subtract(const Duration(minutes: 5));
      expect(timeAgo(dt), '5m ago');
    });

    test('returns hours ago', () {
      final dt = DateTime.now().subtract(const Duration(hours: 3));
      expect(timeAgo(dt), '3h ago');
    });

    test('returns days ago', () {
      final dt = DateTime.now().subtract(const Duration(days: 7));
      expect(timeAgo(dt), '7d ago');
    });

    test('returns 1m ago at exactly 1 minute', () {
      final dt = DateTime.now().subtract(const Duration(minutes: 1));
      expect(timeAgo(dt), '1m ago');
    });

    test('returns 1h ago at exactly 1 hour', () {
      final dt = DateTime.now().subtract(const Duration(hours: 1));
      expect(timeAgo(dt), '1h ago');
    });

    test('returns 1d ago at exactly 1 day', () {
      final dt = DateTime.now().subtract(const Duration(days: 1));
      expect(timeAgo(dt), '1d ago');
    });
  });

  group('timeAgoShort', () {
    test('returns "now" for less than a minute ago', () {
      final dt = DateTime.now().subtract(const Duration(seconds: 10));
      expect(timeAgoShort(dt), 'now');
    });

    test('returns minutes short form', () {
      final dt = DateTime.now().subtract(const Duration(minutes: 15));
      expect(timeAgoShort(dt), '15m');
    });

    test('returns hours short form', () {
      final dt = DateTime.now().subtract(const Duration(hours: 8));
      expect(timeAgoShort(dt), '8h');
    });

    test('returns days short form', () {
      final dt = DateTime.now().subtract(const Duration(days: 30));
      expect(timeAgoShort(dt), '30d');
    });
  });
}
