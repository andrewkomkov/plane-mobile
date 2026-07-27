String htmlToMarkdown(String html) {
  var md = html;
  md = md.replaceAll(RegExp(r'<br\s*/?>'), '\n');
  md = md.replaceAll('</p>', '\n\n');
  md = md.replaceAll(RegExp(r'<p[^>]*>'), '');
  md = md.replaceAllMapped(
      RegExp(r'<h1[^>]*>(.*?)</h1>'), (m) => '# ${m[1]}\n\n');
  md = md.replaceAllMapped(
      RegExp(r'<h2[^>]*>(.*?)</h2>'), (m) => '## ${m[1]}\n\n');
  md = md.replaceAllMapped(
      RegExp(r'<h3[^>]*>(.*?)</h3>'), (m) => '### ${m[1]}\n\n');
  md = md.replaceAllMapped(
      RegExp(r'<strong>(.*?)</strong>'), (m) => '**${m[1]}**');
  md = md.replaceAllMapped(RegExp(r'<b>(.*?)</b>'), (m) => '**${m[1]}**');
  md = md.replaceAllMapped(RegExp(r'<em>(.*?)</em>'), (m) => '*${m[1]}*');
  md = md.replaceAllMapped(RegExp(r'<i>(.*?)</i>'), (m) => '*${m[1]}*');
  md = md.replaceAllMapped(RegExp(r'<code>(.*?)</code>'), (m) => '`${m[1]}`');
  md = md.replaceAllMapped(RegExp(r'<a[^>]+href="([^"]*)"[^>]*>(.*?)</a>'),
      (m) => '[${m[2]}](${m[1]})');
  md = md.replaceAllMapped(RegExp(r'<li>(.*?)</li>'), (m) => '- ${m[1]}\n');
  md = md.replaceAll(RegExp(r'</?[uo]l[^>]*>'), '\n');
  md = md.replaceAllMapped(
      RegExp(r'<blockquote>(.*?)</blockquote>', dotAll: true),
      (m) => '> ${m[1]}\n');
  md = md.replaceAll(RegExp(r'<[^>]*>'), '');
  md = md.replaceAll('&amp;', '&');
  md = md.replaceAll('&lt;', '<');
  md = md.replaceAll('&gt;', '>');
  md = md.replaceAll('&quot;', '"');
  md = md.replaceAll('&#39;', "'");
  md = md.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return md.trim();
}
