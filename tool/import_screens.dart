// Imports the app screenshots listed in src/screens.json into
// assets/img/screens/ as WebP, and keeps the README licence row in step.
//
// Usage (from the repository root):
//   dart tool/import_screens.dart <path-to>/grundschrift_flutter/build/website_screenshots
//
// The screenshots show protected illustrations and icons (see ueber.html).
// While "illustrations_allowed" is false, only the cropped variant of each
// screenshot is written (<key>.webp, from its "crop" box [x, y, width,
// height] in source pixels); screenshots without a crop are left out. When
// it is true, the full screenshots are written (<key>-full.webp). Files of
// the other variant are deleted, so protected material never stays behind.
// Run dart tool/build.dart afterwards.
//
// Needs cwebp (libwebp) on the PATH.
import 'dart:convert';
import 'dart:io';

const _width = 1400; // output width in pixels: 2× the widest figure slot
const _quality = '80';
const _outDir = 'assets/img/screens';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart tool/import_screens.dart <screenshot directory>');
    exit(64);
  }
  final source = Directory(args.single);
  final config = jsonDecode(File('src/screens.json').readAsStringSync()) as Map<String, dynamic>;
  final full = config['illustrations_allowed'] as bool;
  final screens = (config['screens'] as Map).cast<String, Map<String, dynamic>>();
  Directory(_outDir).createSync(recursive: true);

  final keep = <String>{};
  for (final MapEntry(key: key, value: s) in screens.entries) {
    final crop = (s['crop'] as List?)?.cast<int>();
    if (!full && crop == null) continue;
    final out = '$_outDir/$key${full ? '-full' : ''}.webp';
    final input = '${source.path}/${s['source']}';
    final result = Process.runSync('cwebp', [
      '-quiet', '-q', _quality, '-m', '6',
      if (!full) ...['-crop', ...crop!.map((v) => '$v')],
      '-resize', '$_width', '0',
      input, '-o', out,
    ]);
    if (result.exitCode != 0) {
      stderr.writeln('cwebp failed for $input:\n${result.stderr}');
      exit(1);
    }
    keep.add(out);
    stdout.writeln('wrote $out');
  }

  for (final f in Directory(_outDir).listSync().whereType<File>()) {
    final path = '$_outDir/${f.uri.pathSegments.last}';
    if (!keep.contains(path)) {
      f.deleteSync();
      stdout.writeln('removed $path');
    }
  }

  final readme = File('README.md');
  final row = (config['licence'] as Map)[full ? 'full' : 'cropped']['readme'] as String;
  final updated = readme.readAsStringSync().replaceFirstMapped(
    RegExp(r'^\| `assets/img/screens/` \|.*$', multiLine: true),
    (_) => row,
  );
  if (!updated.contains(row)) {
    stderr.writeln('README.md: no `assets/img/screens/` row in the asset table');
    exit(1);
  }
  readme.writeAsStringSync(updated);
  stdout.writeln('updated README.md licence row');
}
