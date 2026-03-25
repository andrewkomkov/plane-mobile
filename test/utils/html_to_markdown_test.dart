import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/utils/html_to_markdown.dart';

void main() {
  group('htmlToMarkdown', () {
    test('converts h1 tags', () {
      expect(htmlToMarkdown('<h1>Title</h1>'), '# Title');
    });

    test('converts h2 tags', () {
      expect(htmlToMarkdown('<h2>Subtitle</h2>'), '## Subtitle');
    });

    test('converts h3 tags', () {
      expect(htmlToMarkdown('<h3>Section</h3>'), '### Section');
    });

    test('converts strong tags to bold', () {
      expect(htmlToMarkdown('<strong>bold</strong>'), '**bold**');
    });

    test('converts b tags to bold', () {
      expect(htmlToMarkdown('<b>bold</b>'), '**bold**');
    });

    test('converts em tags to italic', () {
      expect(htmlToMarkdown('<em>italic</em>'), '*italic*');
    });

    test('converts i tags to italic', () {
      expect(htmlToMarkdown('<i>italic</i>'), '*italic*');
    });

    test('converts code tags to inline code', () {
      expect(htmlToMarkdown('<code>foo()</code>'), '`foo()`');
    });

    test('converts anchor tags to markdown links', () {
      expect(
        htmlToMarkdown('<a href="https://example.com">Link</a>'),
        '[Link](https://example.com)',
      );
    });

    test('converts list items', () {
      final result = htmlToMarkdown('<ul><li>Item 1</li><li>Item 2</li></ul>');
      expect(result, contains('- Item 1'));
      expect(result, contains('- Item 2'));
    });

    test('converts br tags to newlines', () {
      expect(htmlToMarkdown('Line 1<br>Line 2'), 'Line 1\nLine 2');
    });

    test('converts self-closing br tags', () {
      expect(htmlToMarkdown('Line 1<br/>Line 2'), 'Line 1\nLine 2');
    });

    test('converts paragraph tags', () {
      final result = htmlToMarkdown('<p>First</p><p>Second</p>');
      expect(result, contains('First'));
      expect(result, contains('Second'));
    });

    test('decodes HTML entities: &amp;', () {
      expect(htmlToMarkdown('A &amp; B'), 'A & B');
    });

    test('decodes HTML entities: &lt; and &gt;', () {
      expect(htmlToMarkdown('&lt;tag&gt;'), '<tag>');
    });

    test('decodes HTML entities: &quot;', () {
      expect(htmlToMarkdown('&quot;hello&quot;'), '"hello"');
    });

    test('decodes HTML entities: &#39;', () {
      expect(htmlToMarkdown("it&#39;s"), "it's");
    });

    test('strips unknown HTML tags', () {
      expect(htmlToMarkdown('<div>content</div>'), 'content');
    });

    test('handles empty string', () {
      expect(htmlToMarkdown(''), '');
    });

    test('handles plain text without HTML', () {
      expect(htmlToMarkdown('Just plain text'), 'Just plain text');
    });

    test('collapses multiple newlines', () {
      expect(htmlToMarkdown('<p>A</p><p></p><p>B</p>'), 'A\n\nB');
    });

    test('converts blockquote', () {
      final result = htmlToMarkdown('<blockquote>Quote</blockquote>');
      expect(result, contains('> Quote'));
    });
  });
}
