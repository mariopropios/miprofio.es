// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import '../constants/seo_constants.dart';

void applyWebSeoMeta({
  required String title,
  required String description,
  String? canonicalPath,
}) {
  html.document.title = title;
  _setMeta('description', description);
  _setMetaProperty('og:title', title);
  _setMetaProperty('og:description', description);

  if (canonicalPath != null && canonicalPath.isNotEmpty) {
    final path = canonicalPath.startsWith('/')
        ? canonicalPath
        : '/$canonicalPath';
    final url = '${SeoConstants.siteUrl}$path';
    _setCanonical(url);
    _setMetaProperty('og:url', url);
  }
}

void _setMeta(String name, String content) {
  final head = html.document.head;
  if (head == null) return;
  html.MetaElement meta = head.querySelector('meta[name="$name"]')
          as html.MetaElement? ??
      html.MetaElement()
    ..name = name;
  if (meta.parent == null) head.append(meta);
  meta.content = content;
}

void _setMetaProperty(String property, String content) {
  final head = html.document.head;
  if (head == null) return;
  html.MetaElement meta =
      head.querySelector('meta[property="$property"]') as html.MetaElement? ??
          html.MetaElement()
            ..setAttribute('property', property);
  if (meta.parent == null) head.append(meta);
  meta.content = content;
}

void _setCanonical(String href) {
  final head = html.document.head;
  if (head == null) return;
  html.LinkElement link =
      head.querySelector('link[rel="canonical"]') as html.LinkElement? ??
          html.LinkElement()
            ..rel = 'canonical';
  if (link.parent == null) head.append(link);
  link.href = href;
}
