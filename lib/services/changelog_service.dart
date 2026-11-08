import 'package:flutter/services.dart';

/// Una versión parseada del CHANGELOG.md.
class ChangelogEntry {
  final String version;
  final DateTime date;
  final List<String> changes;

  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });
}

/// Lee y parsea `CHANGELOG.md` (raíz del proyecto, registrado como asset) en una lista de [ChangelogEntry].
///
/// Formato esperado (Markdown):
/// ```
/// ## [1.2.3] – AAAA-MM-DD
/// - Cambio uno
/// - Cambio dos
/// ```
abstract final class ChangelogService {
  static List<ChangelogEntry>? _cache;

  /// Devuelve todas las entradas, la más reciente primero.
  static Future<List<ChangelogEntry>> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('CHANGELOG.md');
      _cache = _parse(raw);
    } catch (_) {
      _cache = [];
    }
    return _cache!;
  }

  /// Devuelve la entrada de [version] o `null` si no existe.
  static Future<ChangelogEntry?> entryFor(String version) async {
    final entries = await load();
    try {
      return entries.firstWhere((e) => e.version == version);
    } catch (_) {
      return null;
    }
  }

  static List<ChangelogEntry> _parse(String raw) {
    final entries = <ChangelogEntry>[];
    // Separa por cabecera de versión "## [x.y.z] – fecha"
    final headerRe = RegExp(
      r'^## \[(\d[\d.]+)\]\s*[–-]\s*(\d{4}-\d{2}-\d{2})',
      multiLine: true,
    );

    final matches = headerRe.allMatches(raw).toList();
    for (int i = 0; i < matches.length; i++) {
      final m = matches[i];
      final version = m.group(1)!;
      final date = DateTime.tryParse(m.group(2)!) ?? DateTime(2000);

      // Texto entre esta cabecera y la siguiente (o fin del archivo)
      final start = m.end;
      final end = i + 1 < matches.length ? matches[i + 1].start : raw.length;
      final block = raw.substring(start, end);

      final changes = block
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.startsWith('- '))
          .map((l) => l.substring(2).trim())
          .where((l) => l.isNotEmpty)
          .toList();

      entries.add(ChangelogEntry(version: version, date: date, changes: changes));
    }
    return entries;
  }
}

