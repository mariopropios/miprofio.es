/// Slug URL en español: minúsculas, sin tildes, `ñ`→`n`, espacios→`-`.
String slugify(String input) {
  final trimmed = input.trim().toLowerCase();
  if (trimmed.isEmpty) return '';

  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final buf = StringBuffer();
  for (final rune in trimmed.runes) {
    final ch = String.fromCharCode(rune);
    final idx = from.indexOf(ch);
    if (idx >= 0) {
      buf.write(to[idx]);
    } else if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
      buf.write(ch);
    } else if (RegExp(r'[\s_/.,;:()+\-]+').hasMatch(ch)) {
      buf.write('-');
    }
  }

  return buf
      .toString()
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}
