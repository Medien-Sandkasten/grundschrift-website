// Builds the static website: renders src/pages/*.html through one shared
// layout (head, header, footer) into the repository root, and writes
// sitemap.xml and robots.txt. Only the Dart SDK is needed.
//
// Usage (from the repository root): dart tool/build.dart
//
// Page source format: a front-matter block, then the page body.
//   ---
//   title: Seitentitel
//   description: Meta description
//   nav: app            (optional: key of the active header/footer entry)
//   robots: noindex     (optional: also keeps the page out of sitemap.xml)
//   ---
//   <section>…</section>
//
// Body placeholders:
//   {{tracer}}        letter demo with letter choice (start page)
//   {{board:<label>}} single letter demo, e.g. {{board:G}}
import 'dart:convert';
import 'dart:io';

const siteUrl = 'https://grundschrift-web.medien-sandkasten.de';
const siteName = 'Grundschrift';

class NavItem {
  const NavItem(this.key, this.label, this.href);
  final String key;
  final String label;
  final String href;
}

const headerNav = [
  NavItem('index', 'Start', '/'),
  NavItem('app', 'Die App', '/app.html'),
  NavItem('schule', 'Für Schulen', '/schule.html'),
  NavItem('sicherheit', 'Datenschutz & Sicherheit', '/sicherheit.html'),
  NavItem('open-source', 'Freie Software', '/open-source.html'),
  NavItem('fragen', 'Fragen', '/fragen.html'),
];

const footerNav = [
  NavItem('ueber', 'Über das Projekt', '/ueber.html'),
  NavItem('kontakt', 'Kontakt', '/kontakt.html'),
  NavItem('datenschutz', 'Datenschutz', '/datenschutz.html'),
];

/// Old URLs that external links may still use → their replacement.
/// GitHub Pages cannot redirect on the server, so each gets a small
/// forwarding page (noindex, not in the sitemap).
const redirects = {
  'features': '/app.html',
  'schulmodus': '/schule.html',
  'galerie': '/app.html',
  'ueber-uns': '/ueber.html',
};

class Page {
  Page(this.name, this.meta, this.body);
  final String name;
  final Map<String, String> meta;
  final String body;

  String get path => name == 'index' ? '/' : '/$name.html';
  bool get indexed => meta['robots'] != 'noindex' && name != '404';
}

late final List<Map<String, dynamic>> letters;

void main() {
  final root = Directory.current.path;
  if (!File('$root/tool/build.dart').existsSync()) {
    stderr.writeln('Run from the repository root: dart tool/build.dart');
    exit(64);
  }
  letters = (jsonDecode(File('$root/src/letters.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  final sources = Directory('$root/src/pages')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.html'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final pages = [for (final f in sources) _parse(f)];
  for (final page in pages) {
    File('$root/${page.name}.html').writeAsStringSync(_render(page));
    stdout.writeln('wrote ${page.name}.html');
  }
  for (final MapEntry(key: name, value: target) in redirects.entries) {
    File('$root/$name.html').writeAsStringSync(_redirect(target));
    stdout.writeln('wrote $name.html → $target');
  }
  File('$root/sitemap.xml').writeAsStringSync(_sitemap(pages));
  File('$root/robots.txt').writeAsStringSync(
    // GitHub Pages publishes the whole repository root, sources included.
    'User-agent: *\nDisallow: /src/\nDisallow: /tool/\n\nSitemap: $siteUrl/sitemap.xml\n',
  );
  stdout.writeln('wrote sitemap.xml, robots.txt');
}

Page _parse(File file) {
  final name = file.uri.pathSegments.last.replaceAll('.html', '');
  final text = file.readAsStringSync();
  final match = RegExp(r'^---\n([\s\S]*?)\n---\n').firstMatch(text);
  if (match == null) {
    throw FormatException('${file.path}: missing front matter');
  }
  final meta = <String, String>{};
  for (final line in match.group(1)!.split('\n')) {
    final i = line.indexOf(':');
    if (i > 0) meta[line.substring(0, i).trim()] = line.substring(i + 1).trim();
  }
  for (final key in ['title', 'description']) {
    if ((meta[key] ?? '').isEmpty) {
      throw FormatException('${file.path}: front matter needs "$key"');
    }
  }
  return Page(name, meta, text.substring(match.end));
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _render(Page page) {
  final title = page.name == 'index'
      ? page.meta['title']!
      : '${page.meta['title']} – $siteName';
  final description = _esc(page.meta['description']!);
  final canonical = '$siteUrl${page.path}';
  final robots = page.meta['robots'] == null
      ? ''
      : '\n  <meta name="robots" content="${_esc(page.meta['robots']!)}">';
  final body = _expand(page.body);

  return '''<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${_esc(title)}</title>
  <meta name="description" content="$description">$robots
  <link rel="canonical" href="$canonical">
  <meta property="og:type" content="website">
  <meta property="og:locale" content="de_DE">
  <meta property="og:site_name" content="$siteName">
  <meta property="og:title" content="${_esc(page.meta['title']!)}">
  <meta property="og:description" content="$description">
  <meta property="og:url" content="$canonical">
  <meta property="og:image" content="$siteUrl/assets/img/og.png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="Schriftzug Grundschrift neben einem nachgespurten Buchstaben a">
  <meta name="theme-color" content="#1e3a5f">
  <link rel="preload" href="/assets/fonts/grundschrift-gsv.woff2" as="font" type="font/woff2" crossorigin>
  <link rel="stylesheet" href="/css/style.css">
  <link rel="icon" href="/images/grundschrift_icon.png" type="image/png">
  <link rel="apple-touch-icon" href="/apple-touch-icon.png">
  <script>document.documentElement.classList.add('js')</script>
  <script src="/assets/site.js" defer></script>
</head>
<body>
<a class="skip-link" href="#inhalt">Zum Inhalt springen</a>
${_header(page)}
<main id="inhalt" tabindex="-1">
${body.trim()}
</main>
${_footer(page)}
</body>
</html>
''';
}

String _header(Page page) {
  final items = [
    for (final item in headerNav)
      '        <li><a href="${item.href}"'
          '${item.key == page.meta['nav'] ? ' aria-current="page"' : ''}>'
          '${_esc(item.label)}</a></li>',
  ].join('\n');
  return '''<header class="site-header">
  <div class="container header-inner">
    <a class="brand" href="/"${page.name == 'index' ? ' aria-current="page"' : ''}>
      <img src="/images/grundschrift_icon.png" alt="" width="40" height="40">
      <span>Grundschrift</span>
    </a>
    <button class="nav-toggle" type="button" aria-expanded="false" aria-controls="hauptmenue">
      <span class="nav-toggle-bars" aria-hidden="true"></span>
      <span>Menü</span>
    </button>
    <nav class="site-nav" id="hauptmenue" aria-label="Hauptmenü">
      <ul>
$items
      </ul>
    </nav>
  </div>
</header>''';
}

String _footer(Page page) {
  final items = [
    for (final item in footerNav)
      '        <li><a href="${item.href}"'
          '${item.key == page.meta['nav'] ? ' aria-current="page"' : ''}>'
          '${_esc(item.label)}</a></li>',
  ].join('\n');
  return '''<footer class="site-footer">
  <div class="container footer-inner">
    <p class="footer-brand">Grundschrift</p>
    <nav aria-label="Weitere Seiten">
      <ul class="footer-links">
$items
      </ul>
    </nav>
    <p class="footer-note">
      Grundschrift ist ein Projekt von Medien-Sandkasten, freie Software unter der AGPL-3.0. Version&nbsp;2.0 ist noch nicht veröffentlicht.<br>
      Schrift: Grundschrift GSV, <a href="/assets/fonts/OFL.txt">SIL Open Font License&nbsp;1.1</a>.
    </p>
  </div>
</footer>''';
}

String _expand(String body) => body
    .replaceAll('{{tracer}}', _tracer())
    .replaceAllMapped(
      RegExp(r'\{\{board:([^}]+)\}\}'),
      (m) => _board(m.group(1)!.trim()),
    );

Map<String, dynamic> _letter(String label) => letters.firstWhere(
  (l) => l['label'] == label,
  orElse: () => throw ArgumentError('unknown letter "$label" in src/letters.json'),
);

/// Vertical slice of the 787-unit level canvas shown on the board. All levels
/// share it, so the four writing lines sit at the same height for every letter.
const _top = 20;
const _height = 730;

const _categoryNames = {
  'GROSSBUCHSTABEN': 'Großbuchstabe',
  'kleinbuchstaben': 'Kleinbuchstabe',
  'zahlen': 'Ziffer',
  'verbindungen': 'Verbindung',
};

String _describe(Map<String, dynamic> l) =>
    '${_categoryNames[l['category']] ?? 'Zeichen'} ${l['label']}';

/// One letter as inline SVG: open level background, the stroke path as ink,
/// the anchor points, and the app's demo finger.
String _svg(Map<String, dynamic> l, {required String id, bool deferImage = false}) {
  final w = l['width'] as num;
  final lineWidth = (l['lineWidth'] as num) * 0.42;
  final strokes = (l['strokes'] as List).cast<String>();
  final anchors = (l['anchors'] as List).cast<List>();
  final hrefAttr = deferImage ? 'data-href' : 'href';
  final paths = [
    for (var i = 0; i < strokes.length; i++)
      '<path class="ink" data-stroke="$i" d="${strokes[i]}"/>',
  ].join();
  final dots = [
    for (final a in anchors)
      '<circle class="anchor" data-stroke="${a[2]}" data-at="${a[3]}" '
          'cx="${a[0]}" cy="${a[1]}" r="${(lineWidth * 0.62).toStringAsFixed(1)}"/>',
  ].join();
  return '<svg class="board-svg" viewBox="0 $_top $w $_height" role="img" '
      'aria-labelledby="$id-t">'
      '<title id="$id-t">Schreibweg: ${_describe(l)}</title>'
      // Fades out the forearm of the finger photo, which ends in a hard edge.
      '<defs><linearGradient id="$id-fade" x1="0" y1="0" x2="0.55" y2="1">'
      '<stop offset="0.55" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0"/>'
      '</linearGradient><mask id="$id-mask" maskContentUnits="objectBoundingBox">'
      '<rect width="1" height="1" fill="url(#$id-fade)"/></mask></defs>'
      '<image $hrefAttr="${l['background']}" x="0" y="0" width="$w" height="787" '
      'preserveAspectRatio="xMidYMid meet"/>'
      '<g class="inks" fill="none" stroke-width="${lineWidth.toStringAsFixed(1)}" '
      'stroke-linecap="round" stroke-linejoin="round">$paths</g>'
      '<g class="anchors">$dots</g>'
      '<image class="finger" href="/assets/img/finger.png" x="0" y="0" width="140" height="196" '
      'mask="url(#$id-mask)" aria-hidden="true"/>'
      '</svg>';
}

String _board(String label) {
  final l = _letter(label);
  final id = 'b-${_slug(label)}';
  return '''<figure class="board board-small" data-tracer data-autoplay="visible">
  <div class="board-paper">${_svg(l, id: id)}</div>
  <figcaption>
    <span>${_describe(l)}</span>
    <button class="replay" type="button" aria-label="Nochmal zeigen: ${_describe(l)}">Nochmal zeigen</button>
  </figcaption>
</figure>''';
}

String _tracer() {
  const order = ['a', 'G', 'f', 'ß', '3', 'ei'];
  final boards = StringBuffer();
  final choices = StringBuffer();
  for (var i = 0; i < order.length; i++) {
    final l = _letter(order[i]);
    final id = 't-${_slug(order[i])}';
    boards.write(
      '<div class="tracer-slot" data-letter="${_slug(order[i])}"${i == 0 ? '' : ' hidden'}>'
      '${_svg(l, id: id, deferImage: i != 0)}</div>',
    );
    choices.write(
      '<button type="button" class="letter-choice" data-letter="${_slug(order[i])}" '
      'aria-pressed="${i == 0}" aria-label="${_describe(l)}">${l['label']}</button>',
    );
  }
  return '''<figure class="board board-hero" data-tracer data-autoplay="load">
  <div class="board-paper">$boards</div>
  <figcaption>
    <span class="board-caption">So führt die App einen Buchstaben vor. Danach spurt das Kind selbst nach.</span>
    <span class="board-controls">
      <span class="letter-choices" role="group" aria-label="Buchstabe wählen">$choices</span>
      <button class="replay" type="button">Nochmal zeigen</button>
    </span>
  </figcaption>
</figure>''';
}

String _slug(String label) => switch (label) {
  'ß' => 'sz',
  _ when label.toUpperCase() == label && label.toLowerCase() != label => 'gross-${label.toLowerCase()}',
  _ => label.toLowerCase(),
};

String _redirect(String target) => '''<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Diese Seite ist umgezogen – $siteName</title>
  <meta name="robots" content="noindex">
  <link rel="canonical" href="$siteUrl$target">
  <meta http-equiv="refresh" content="0; url=$target">
  <link rel="stylesheet" href="/css/style.css">
</head>
<body>
<main class="container section">
  <h1>Diese Seite ist umgezogen</h1>
  <p class="lead">Weiter zur neuen Seite: <a href="$target">$siteUrl$target</a></p>
</main>
</body>
</html>
''';

String _sitemap(List<Page> pages) {
  final urls = [
    for (final p in [
      ...pages.where((p) => p.indexed && p.name == 'index'),
      ...pages.where((p) => p.indexed && p.name != 'index'),
    ])
      '  <url><loc>$siteUrl${p.path}</loc></url>',
  ].join('\n');
  return '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n$urls\n</urlset>\n';
}
