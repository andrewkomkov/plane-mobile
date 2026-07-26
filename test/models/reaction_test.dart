import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/reaction.dart';

void main() {
  // Plane does not store emoji. It stores the decimal Unicode code point as a
  // string, and its web client renders with String.fromCodePoint. Posting a
  // literal emoji from here would be stored verbatim and would never group
  // with the web's reactions, leaving two thumbs-up chips on one work item.
  group('Reaction.codeToEmoji', () {
    test('renders a code point above the BMP as a surrogate pair', () {
      // 128077 is U+1F44D, which does not fit in one UTF-16 code unit.
      expect(Reaction.codeToEmoji('128077'), '\u{1F44D}');
      expect(Reaction.codeToEmoji('128077').runes.single, 0x1F44D);
    });

    test('renders a code point inside the BMP', () {
      expect(Reaction.codeToEmoji('9992'), '✈');
    });

    test('renders every code the picker offers', () {
      for (final code in kReactionEmojiCodes) {
        final emoji = Reaction.codeToEmoji(code);
        expect(emoji, isNotEmpty);
        expect(emoji, isNot(code), reason: '$code should not pass through');
      }
    });

    // Matches the web helper's isNaN fallback: a client that wrote a literal
    // emoji should still display, not disappear.
    test('passes a non-numeric value through unchanged', () {
      expect(Reaction.codeToEmoji('👍'), '👍');
      expect(Reaction.codeToEmoji(''), '');
    });

    test('passes through a number outside the Unicode range', () {
      // fromCharCode throws on these rather than returning something drawable.
      expect(Reaction.codeToEmoji('99999999'), '99999999');
      expect(Reaction.codeToEmoji('-1'), '-1');
    });
  });

  group('Reaction.fromJson', () {
    // The work item serialiser sends a nested actor_detail object.
    test('reads the work item shape with a nested actor_detail', () {
      final r = Reaction.fromJson({
        'id': 'r1',
        'reaction': '128077',
        'actor': 'user-1',
        'actor_detail': {'id': 'user-1', 'display_name': 'Ada'},
      });
      expect(r.id, 'r1');
      expect(r.reaction, '128077');
      expect(r.actor, 'user-1');
      expect(r.displayName, 'Ada');
      expect(r.emoji, '\u{1F44D}');
    });

    // The comment serialiser sends a flat display_name and no actor_detail.
    test('reads the comment shape with a flat display_name', () {
      final r = Reaction.fromJson({
        'id': 'r2',
        'reaction': '128064',
        'actor': 'user-2',
        'display_name': 'Grace',
      });
      expect(r.displayName, 'Grace');
      expect(r.actor, 'user-2');
    });

    test('reads an actor that arrived expanded rather than as an id', () {
      final r = Reaction.fromJson({
        'id': 'r3',
        'reaction': '128078',
        'actor': {'id': 'user-3', 'display_name': 'Linus'},
      });
      expect(r.actor, 'user-3');
    });

    test('survives a row missing everything optional', () {
      final r = Reaction.fromJson({'id': 'r4', 'reaction': '9992'});
      expect(r.actor, isNull);
      expect(r.displayName, isNull);
    });
  });

  group('groupReactions', () {
    test('collapses identical emoji into one group with a count', () {
      final groups = groupReactions([
        Reaction(id: '1', reaction: '128077', actor: 'a'),
        Reaction(id: '2', reaction: '128077', actor: 'b'),
        Reaction(id: '3', reaction: '128064', actor: 'c'),
      ], null);

      expect(groups.length, 2);
      expect(groups.first.reaction, '128077');
      expect(groups.first.count, 2);
      expect(groups.last.reaction, '128064');
      expect(groups.last.count, 1);
    });

    test('marks the group the current user is part of', () {
      final groups = groupReactions([
        Reaction(id: '1', reaction: '128077', actor: 'me'),
        Reaction(id: '2', reaction: '128064', actor: 'someone-else'),
      ], 'me');

      expect(
          groups.firstWhere((g) => g.reaction == '128077').reactedByMe, isTrue);
      expect(groups.firstWhere((g) => g.reaction == '128064').reactedByMe,
          isFalse);
    });

    // An empty or absent viewer id must not match a row with no actor, or the
    // toggle would try to delete reactions belonging to other people.
    test('claims nothing when the current user is unknown', () {
      final groups = groupReactions([
        Reaction(id: '1', reaction: '128077', actor: null),
        Reaction(id: '2', reaction: '128064', actor: 'someone'),
      ], null);
      expect(groups.every((g) => !g.reactedByMe), isTrue);

      final withEmpty = groupReactions([
        Reaction(id: '1', reaction: '128077', actor: null),
      ], '');
      expect(withEmpty.single.reactedByMe, isFalse);
    });

    // Chips that reorder under the finger are hard to hit.
    test('keeps first-appearance order rather than sorting by count', () {
      final groups = groupReactions([
        Reaction(id: '1', reaction: '128064', actor: 'a'),
        Reaction(id: '2', reaction: '128077', actor: 'b'),
        Reaction(id: '3', reaction: '128077', actor: 'c'),
        Reaction(id: '4', reaction: '128077', actor: 'd'),
      ], null);

      expect(groups.map((g) => g.reaction), ['128064', '128077']);
      expect(groups.first.count, 1);
      expect(groups.last.count, 3);
    });

    test('collects the reactors names for the label', () {
      final groups = groupReactions([
        Reaction(id: '1', reaction: '128077', actor: 'a', displayName: 'Ada'),
        Reaction(id: '2', reaction: '128077', actor: 'b', displayName: 'Bob'),
        Reaction(id: '3', reaction: '128077', actor: 'c'),
      ], null);
      expect(groups.single.actorNames, ['Ada', 'Bob']);
      expect(groups.single.count, 3);
    });

    test('drops rows carrying no emoji at all', () {
      final groups = groupReactions([
        Reaction(id: '1', reaction: '', actor: 'a'),
      ], null);
      expect(groups, isEmpty);
    });

    test('returns nothing for no reactions', () {
      expect(groupReactions([], 'me'), isEmpty);
    });
  });
}
