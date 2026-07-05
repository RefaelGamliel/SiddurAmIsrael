import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static integrity guard for the prayer asset graph.
///
/// Every prayer is assembled by resolving template + segment references through
/// `assets/prayers/_manifest.json`. A reference that points nowhere throws only
/// at runtime — and only on the specific day/nusach that triggers it (e.g. a
/// fast-day selichot template, or a Purim-only segment). These tests resolve
/// the ENTIRE graph statically so any broken reference fails CI immediately,
/// regardless of the date, nusach, or condition flags that would surface it.
///
/// Uses dart:io (not rootBundle): `flutter test` runs from the package root, so
/// the asset files are read straight from disk without an AssetBundle.
void main() {
  const nuschaot = ['ashkenaz', 'sfard', 'edot_mizrach'];
  const templatesDir = 'assets/prayers/templates';

  final manifest = jsonDecode(
    File('assets/prayers/_manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  Map<String, String> strMap(dynamic raw) => raw is Map
      ? raw.map((k, v) => MapEntry(k as String, v as String))
      : <String, String>{};

  final templates = strMap(manifest['templates']);
  final common = strMap(manifest['common']);
  final nusach = <String, Map<String, String>>{
    for (final e in (manifest['nusach'] as Map? ?? {}).entries)
      e.key as String: strMap(e.value),
  };

  bool fileExists(String rel) => File(rel).existsSync();

  // Mirrors PrayerLocalDatasource.loadTemplate: manifest override, else the
  // conventional templates/{id}.json path.
  String templatePath(String id) =>
      templates[id] ?? '$templatesDir/$id.json';

  // Mirrors PrayerLocalDatasource.loadNusachSegment: nusach override, else
  // common. There is NO path fallback for segments.
  bool segmentResolvesFor(String id, String n) =>
      (nusach[n]?.containsKey(id) ?? false) || common.containsKey(id);

  bool segmentResolvesAnywhere(String id) =>
      common.containsKey(id) || nusach.values.any((m) => m.containsKey(id));

  Map<String, dynamic> readJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  List<Map<String, dynamic>> segmentsOf(Map<String, dynamic> tpl) =>
      ((tpl['segments'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();

  group('prayer asset reference integrity', () {
    test('every manifest path points to an existing asset file', () {
      final missing = <String>[];
      void check(Map<String, String> m, String label) {
        m.forEach((k, p) {
          if (!fileExists(p)) missing.add('$label["$k"] -> $p');
        });
      }

      check(templates, 'templates');
      check(common, 'common');
      nusach.forEach((n, m) => check(m, 'nusach.$n'));

      expect(missing, isEmpty,
          reason: 'Manifest entries pointing at missing files:\n'
              '${missing.join('\n')}');
    });

    test('every reference in every template file resolves', () {
      final problems = <String>[];
      for (final entity in Directory(templatesDir).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        final tpl = readJson(entity.path);
        for (final seg in segmentsOf(tpl)) {
          final sub = seg['sub_template_id'] as String?;
          final segId = seg['segment_id'] as String?;
          if (sub != null) {
            final p = templatePath(sub);
            if (!fileExists(p)) {
              problems.add('${entity.path}: sub_template_id "$sub" -> $p (missing)');
            }
          } else if (segId != null) {
            if (!segmentResolvesAnywhere(segId)) {
              problems.add('${entity.path}: segment_id "$segId" '
                  'not found in common or any nusach map');
            }
          }
        }
      }
      expect(problems, isEmpty,
          reason: 'Unresolvable references in template files:\n'
              '${problems.join('\n')}');
    });

    test('every service fully resolves for each nusach (recursive)', () {
      final problems = <String>[];

      void walk(String templateId, String n, String chain, Set<String> seen) {
        if (!seen.add('$templateId|$n')) return;
        final p = templatePath(templateId);
        if (!fileExists(p)) {
          problems.add('[$n] missing template "$templateId" -> $p (via $chain)');
          return;
        }
        for (final seg in segmentsOf(readJson(p))) {
          // A segment/sub-template restricted to other nuschaot is never loaded
          // for this one, so skip it — mirrors the assembler's nusach filter.
          final allowed = (seg['allowed_nusach'] as List?)?.cast<String>();
          if (allowed != null && allowed.isNotEmpty && !allowed.contains(n)) {
            continue;
          }
          // Condition flags are intentionally ignored: we want to exercise
          // EVERY conditional path (fasts, Purim, Musaf, Chanukah, …).
          final sub = seg['sub_template_id'] as String?;
          final segId = seg['segment_id'] as String?;
          if (sub != null) {
            walk(sub, n, '$chain > $sub', seen);
          } else if (segId != null && !segmentResolvesFor(segId, n)) {
            problems.add('[$n] segment "$segId" unresolved '
                '(in $templateId, via $chain)');
          }
        }
      }

      // The exact root templates the providers assemble (see prayer_providers).
      // Musaf and Sefirat HaOmer are reached recursively via Shacharit/Maariv.
      for (final n in nuschaot) {
        final seen = <String>{};
        final roots = [
          'shacharit_$n',
          'maariv_$n',
          'birkat_hamazon_$n',
          'meein_shalosh_$n',
          'tefilat_haderech_$n',
          'mincha', // shared template, resolved per-nusach
        ];
        for (final r in roots) {
          walk(r, n, r, seen);
        }
      }

      expect(problems, isEmpty,
          reason: 'Per-nusach resolution failures:\n${problems.join('\n')}');
    });
  });
}
