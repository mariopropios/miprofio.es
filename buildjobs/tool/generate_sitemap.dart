// Genera web/sitemap.xml con hubs SEO local + oficio×pueblo.
// Uso: dart run tool/generate_sitemap.dart
// (desde buildjobs; requiere package config)

import 'dart:io';

import 'package:buildjobs/core/constants/local_seo.dart';
import 'package:buildjobs/core/constants/seo_constants.dart';

void main() {
  final urls = <String>[
    '${SeoConstants.siteUrl}/',
    '${SeoConstants.siteUrl}/search',
    '${SeoConstants.siteUrl}/about',
    for (final path in LocalSeo.allIndexablePaths())
      '${SeoConstants.siteUrl}$path',
  ];

  final buf = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    );

  for (var i = 0; i < urls.length; i++) {
    final loc = urls[i];
    final priority = loc.endsWith('/')
        ? '1.0'
        : loc.contains('/search')
            ? '0.5'
            : loc.split('/').length <= 4
                ? '0.9'
                : '0.8';
    buf
      ..writeln('  <url>')
      ..writeln('    <loc>$loc</loc>')
      ..writeln('    <changefreq>weekly</changefreq>')
      ..writeln('    <priority>$priority</priority>')
      ..writeln('  </url>');
  }
  buf.writeln('</urlset>');

  final out = File('web/sitemap.xml');
  out.writeAsStringSync(buf.toString());
  stderr.writeln('Wrote ${out.path} (${urls.length} urls)');
}
