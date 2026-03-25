String markdownToHtml(String md) {
  var html = md;

  // Headings (must be before other replacements)
  html = html.replaceAllMapped(
      RegExp(r'^### (.+)$', multiLine: true), (m) => '<h3>${m[1]}</h3>');
  html = html.replaceAllMapped(
      RegExp(r'^## (.+)$', multiLine: true), (m) => '<h2>${m[1]}</h2>');
  html = html.replaceAllMapped(
      RegExp(r'^# (.+)$', multiLine: true), (m) => '<h1>${m[1]}</h1>');

  // Bold
  html = html.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'), (m) => '<strong>${m[1]}</strong>');

  // Italic
  html = html.replaceAllMapped(
      RegExp(r'\*(.+?)\*'), (m) => '<em>${m[1]}</em>');

  // Inline code
  html =
      html.replaceAllMapped(RegExp(r'`(.+?)`'), (m) => '<code>${m[1]}</code>');

  // Links
  html = html.replaceAllMapped(
      RegExp(r'\[(.+?)\]\((.+?)\)'), (m) => '<a href="${m[2]}">${m[1]}</a>');

  // Unordered list items
  html = html.replaceAllMapped(
      RegExp(r'^- (.+)$', multiLine: true), (m) => '<li>${m[1]}</li>');

  // Blockquotes
  html = html.replaceAllMapped(
      RegExp(r'^> (.+)$', multiLine: true),
      (m) => '<blockquote>${m[1]}</blockquote>');

  // Wrap remaining paragraphs
  final lines = html.split('\n');
  final buffer = StringBuffer();
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    if (trimmed.startsWith('<h') ||
        trimmed.startsWith('<li') ||
        trimmed.startsWith('<blockquote')) {
      buffer.writeln(trimmed);
    } else {
      buffer.writeln('<p>$trimmed</p>');
    }
  }

  return buffer.toString().trim();
}
