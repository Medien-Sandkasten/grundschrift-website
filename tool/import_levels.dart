// Imports a few open (AGPL-3.0) level folders from the Grundschrift app into
// this website: the level background SVG goes to assets/levels/, the stroke
// paths from metadata.json go to src/letters.json for tool/build.dart.
//
// Only level data is read. Illustrations and recordings of the app are
// third-party material and must never be imported here.
//
// Usage: dart tool/import_levels.dart <path-to>/grundschrift_flutter/assets/levels
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Level folder → label shown on the website.
const levels = <String, String>{
  'kleinbuchstaben/a': 'a',
  'GROSSBUCHSTABEN/G': 'G',
  'kleinbuchstaben/f': 'f',
  'kleinbuchstaben/sz': 'ß',
  'zahlen/3': '3',
  'verbindungen/ei': 'ei',
};

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart tool/import_levels.dart <levels-dir>');
    exit(64);
  }
  final root = Directory.current.path;
  final outDir = Directory('$root/assets/levels')..createSync(recursive: true);
  final letters = <Map<String, Object>>[];

  for (final entry in levels.entries) {
    final dir = '${args.first}/${entry.key}';
    final meta = jsonDecode(File('$dir/metadata.json').readAsStringSync())
        as Map<String, dynamic>;
    final svg = File('$dir/background.svg').readAsStringSync();
    final viewBox = RegExp(r'viewBox\s*=\s*"([^"]+)"').firstMatch(svg)!.group(1)!;
    final size = viewBox.trim().split(RegExp(r'[\s,]+')).map(double.parse).toList();

    final id = entry.key.split('/').last.toLowerCase();
    final fileName = '${meta['category'].toString().toLowerCase()}-$id.svg';
    File('${outDir.path}/$fileName').writeAsStringSync(_roundNumbers(svg));

    final strokes = <String>[];
    // [x, y, stroke index, position along the stroke from 0 to 1]
    final anchors = <List<num>>[];
    final paths = meta['paths'] as List;
    for (var s = 0; s < paths.length; s++) {
      final path = paths[s] as List;
      final points = [
        for (final p in path)
          math.Point<double>((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
      ];
      strokes.add(_smoothPath(points));
      final cumulative = <double>[0];
      for (var i = 1; i < points.length; i++) {
        cumulative.add(cumulative.last + points[i].distanceTo(points[i - 1]));
      }
      for (var i = 0; i < path.length; i++) {
        if (path[i]['isAnchor'] == true) {
          final t = cumulative.last == 0 ? 0.0 : cumulative[i] / cumulative.last;
          anchors.add([_r(points[i].x), _r(points[i].y), s, (t * 1000).round() / 1000]);
        }
      }
    }

    letters.add({
      'label': entry.value,
      'category': meta['category'] as String,
      'width': _r(size[2]),
      'height': _r(size[3]),
      'lineWidth': (meta['lineWidth'] as num?) ?? 48,
      'background': '/assets/levels/$fileName',
      'strokes': strokes,
      'anchors': anchors,
    });
  }

  File('$root/src/letters.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(letters)}\n',
  );
  stdout.writeln('imported ${letters.length} levels');
}

num _r(num v) {
  final rounded = (v * 10).round() / 10;
  return rounded == rounded.roundToDouble() ? rounded.round() : rounded;
}

/// Catmull-Rom spline through the sampled points, written as cubic Béziers.
String _smoothPath(List<math.Point<double>> p) {
  final b = StringBuffer('M${_r(p.first.x)} ${_r(p.first.y)}');
  for (var i = 0; i < p.length - 1; i++) {
    final p0 = i == 0 ? p[i] : p[i - 1];
    final p1 = p[i];
    final p2 = p[i + 1];
    final p3 = i + 2 < p.length ? p[i + 2] : p2;
    final c1x = p1.x + (p2.x - p0.x) / 6, c1y = p1.y + (p2.y - p0.y) / 6;
    final c2x = p2.x - (p3.x - p1.x) / 6, c2y = p2.y - (p3.y - p1.y) / 6;
    b.write('C${_r(c1x)} ${_r(c1y)} ${_r(c2x)} ${_r(c2y)} ${_r(p2.x)} ${_r(p2.y)}');
  }
  return b.toString();
}

/// Shortens long decimals in the traced background to one place.
String _roundNumbers(String svg) => svg.replaceAllMapped(
  RegExp(r'(\d+\.\d)\d+'),
  (m) => m.group(1)!,
);
