// Checks the built website: internal links and assets resolve, every page has
// exactly one h1, the landmarks and meta tags exist, and every text/background
// colour pair used by css/style.css meets WCAG 2.2 AA contrast.
//
// Usage (from the repository root, after dart tool/build.dart):
//   dart tool/check.dart
import 'dart:io';
import 'dart:math' as math;

final failures = <String>[];

void main() {
  final root = Directory.current.path;
  final pages = Directory(root)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.html'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  var links = 0;
  for (final page in pages) {
    final name = page.uri.pathSegments.last;
    final html = page.readAsStringSync();
    final refresh = RegExp(r'<meta http-equiv="refresh" content="0; url=(/[^"]*)">').firstMatch(html);
    if (refresh != null) {
      // Forwarding page for an old URL: target must exist, never indexed.
      links++;
      _checkPath(root, name, refresh.group(1)!);
      _expectCount(name, html, RegExp(r'<meta name="robots" content="noindex">'), 1, 'noindex');
      _expectCount(name, html, RegExp(r'<link rel="canonical" href="https://[^"]+">'), 1, 'canonical');
      _expectCount(name, html, RegExp(r'<h1[\s>]'), 1, 'h1');
      if (File('$root/sitemap.xml').readAsStringSync().contains('/$name<')) {
        failures.add('$name: forwarding page listed in sitemap.xml');
      }
      continue;
    }
    _expectCount(name, html, RegExp(r'<h1[\s>]'), 1, 'h1');
    _expectCount(name, html, RegExp(r'<main[\s>]'), 1, 'main');
    _expectCount(name, html, RegExp(r'<header[\s>]'), 1, 'header');
    _expectCount(name, html, RegExp(r'<footer[\s>]'), 1, 'footer');
    _expectCount(name, html, RegExp(r'class="skip-link" href="#inhalt"'), 1, 'skip link');
    _expectCount(name, html, RegExp(r'<meta name="description" content="[^"]+">'), 1, 'meta description');
    _expectCount(name, html, RegExp(r'<link rel="canonical" href="https://[^"]+">'), 1, 'canonical');
    _expectCount(name, html, RegExp(r'<html lang="de">'), 1, 'lang');

    final ids = RegExp(r'\sid="([^"]+)"').allMatches(html).map((m) => m.group(1)).toSet();
    for (final m in RegExp(r'\s(?:href|src|data-href)="([^"]+)"').allMatches(html)) {
      final target = m.group(1)!;
      if (RegExp(r'^(https?:|mailto:|data:)').hasMatch(target)) continue;
      links++;
      if (target.startsWith('#')) {
        if (!ids.contains(target.substring(1))) {
          failures.add('$name: fragment $target has no matching id');
        }
        continue;
      }
      _checkPath(root, name, target);
    }
    // SVG url(#…) references must point at an id in the same document.
    for (final m in RegExp(r'url\(#([^)]+)\)').allMatches(html)) {
      if (!ids.contains(m.group(1))) failures.add('$name: url(#${m.group(1)}) has no matching id');
    }
  }

  final css = File('$root/css/style.css').readAsStringSync();
  for (final m in RegExp(r"url\('?(/[^')]+)'?\)").allMatches(css)) {
    links++;
    _checkPath(root, 'css/style.css', m.group(1)!);
  }
  for (final f in ['robots.txt', 'sitemap.xml', 'apple-touch-icon.png', 'assets/img/og.png', 'CNAME']) {
    if (!File('$root/$f').existsSync()) failures.add('missing $f');
  }

  stdout.writeln('${pages.length} pages, $links internal references checked');
  _contrast(css);

  if (failures.isEmpty) {
    stdout.writeln('OK');
  } else {
    stderr.writeln(failures.map((f) => 'FAIL $f').join('\n'));
    exit(1);
  }
}

void _expectCount(String page, String html, RegExp pattern, int expected, String what) {
  final count = pattern.allMatches(html).length;
  if (count != expected) failures.add('$page: $count × $what (expected $expected)');
}

void _checkPath(String root, String from, String target) {
  var path = target.split('#').first.split('?').first;
  if (path.isEmpty) return;
  if (!path.startsWith('/')) {
    failures.add('$from: relative reference $target (use root-relative paths)');
    return;
  }
  if (path == '/') path = '/index.html';
  if (!File('$root$path').existsSync()) failures.add('$from: $target does not exist');
}

// ── Contrast ──────────────────────────────────────────────────────────────

/// Foreground, background, minimum ratio, where it is used.
/// Text needs 4.5:1; large text, focus indicators and control boundaries 3:1.
const _pairs = <(String, String, double, String)>[
  ('--text', '--white', 4.5, 'body text'),
  ('--text', '--paper', 4.5, 'body text on paper sections and draft callouts'),
  ('--muted', '--white', 4.5, 'secondary text, captions'),
  ('--muted', '--paper', 4.5, 'secondary text on paper'),
  ('--blue', '--white', 4.5, 'headings, links, nav, secondary buttons'),
  ('--blue', '--paper', 4.5, 'headings and links on paper'),
  ('--blue', '--blue-tint', 4.5, 'button hover, alphabet letters on the x-height band'),
  ('--orange-text', '--white', 4.5, 'hovered links, step numbers, badges'),
  ('--orange-text', '--paper', 4.5, 'hovered links and badges on paper'),
  ('--white', '--blue', 4.5, 'navy blocks, footer, primary button, pressed letter, skip link'),
  ('--white', '--blue-deep', 4.5, 'primary button hover'),
  ('--on-blue', '--blue', 4.5, 'lead, eyebrow, status and footer note on navy'),
  ('--focus', '--white', 3.0, 'focus ring'),
  ('--focus', '--paper', 3.0, 'focus ring on paper'),
  ('--focus-on-blue', '--blue', 3.0, 'focus ring on navy'),
  ('--blue', '--white', 3.0, 'button and toggle borders'),
  ('--control-line', '--white', 3.0, 'letter choice borders, open table marker'),
  ('--orange', '--white', 3.0, 'current-page bar, readable-data marker'),
];

void _contrast(String css) {
  final vars = <String, String>{
    for (final m in RegExp(r'(--[\w-]+):\s*(#[0-9a-fA-F]{6})\s*;').allMatches(css))
      m.group(1)!: m.group(2)!,
  };
  String resolve(String v) => v.startsWith('--')
      ? (vars[v] ?? (throw StateError('css/style.css does not define $v')))
      : v;

  stdout.writeln('\nContrast (WCAG 2.2 AA):');
  for (final (fg, bg, min, use) in _pairs) {
    final ratio = _ratio(resolve(fg), resolve(bg));
    final ok = ratio >= min;
    stdout.writeln(
      '  ${ok ? 'pass' : 'FAIL'}  ${ratio.toStringAsFixed(2).padLeft(5)}:1  '
      '(min $min)  ${'$fg ${resolve(fg)}'.padRight(24)} on ${'$bg ${resolve(bg)}'.padRight(22)} $use',
    );
    if (!ok) failures.add('contrast $fg on $bg: ${ratio.toStringAsFixed(2)} < $min ($use)');
  }
}

double _ratio(String a, String b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

double _luminance(String hex) {
  final v = int.parse(hex.substring(1), radix: 16);
  double channel(int c) {
    final s = c / 255;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }
  return 0.2126 * channel((v >> 16) & 0xff) +
      0.7152 * channel((v >> 8) & 0xff) +
      0.0722 * channel(v & 0xff);
}
