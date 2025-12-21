import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

class BackupService {
  // Hardcoded list of database files to ensure we don't miss anything or include garbage
  static const List<String> _boxNames = ['transactions', 'categories', 'cards'];

  /// Creates a validated Zip file containing the Hive databases.
  /// Returns the File object of the created zip.
  Future<File> createBackup() async {
    final appDir = await getApplicationDocumentsDirectory();
    print("[BackupService] App Directory: ${appDir.path}");

    // 1. Identify valid database files
    final List<File> filesToBackup = [];
    for (final name in _boxNames) {
      final file = File(p.join(appDir.path, '$name.hive'));
      if (file.existsSync()) {
        filesToBackup.add(file);
        print(
          "[BackupService] Found database: ${file.path} (${file.lengthSync()} bytes)",
        );
      } else {
        print("[BackupService] WARNING: Database file not found: $name.hive");
      }
    }

    if (filesToBackup.isEmpty) {
      throw Exception(
        "Error: No existen datos para respaldar (Archivos .hive no encontrados).",
      );
    }

    // 2. Determine Output Directory (External for Android visibility, Doc for iOS)
    Directory outputDir = appDir;
    if (Platform.isAndroid) {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) outputDir = extDir;
    }

    final zipPath = p.join(outputDir.path, 'cashrapido_backup.zip');
    final zipFile = File(zipPath);

    // 3. Create Zip
    try {
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);

      for (final file in filesToBackup) {
        // Store JUST the filename, no folder paths
        final filename = p.basename(file.path);
        await encoder.addFile(file, filename);
      }

      encoder.close();
    } catch (e) {
      throw Exception("Error comprimiendo archivo de respaldo: $e");
    }

    // 4. Verify Zip Integrity
    if (!zipFile.existsSync() || zipFile.lengthSync() == 0) {
      throw Exception("Error crítico: El archivo de respaldo se creó vacío.");
    }

    print(
      "[BackupService] Backup created successfully at: $zipPath (${zipFile.lengthSync()} bytes)",
    );
    return zipFile;
  }

  /// Restores data from a Zip file, overwriting existing databases.
  /// Throws exception if validation fails.
  Future<void> restoreBackup(File zipFile) async {
    print("[BackupService] Starting restore from: ${zipFile.path}");

    if (!zipFile.existsSync()) {
      throw Exception("El archivo de respaldo no existe.");
    }

    final appDir = await getApplicationDocumentsDirectory();
    final bytes = await zipFile.readAsBytes();

    if (bytes.isEmpty) throw Exception("El archivo de respaldo está vacío.");

    final archive = ZipDecoder().decodeBytes(bytes);
    print("[BackupService] Zip decoded. Found ${archive.files.length} files.");

    int restoredCount = 0;

    for (final file in archive.files) {
      if (!file.isFile) continue;

      final filename = p.basename(file.name);

      // SECURITY: Skip directory traversal attempts
      if (file.name.contains('..')) {
        print("[BackupService] Skipping unsafe file: ${file.name}");
        continue;
      }

      // VALIDATION: Only restore known Hive files
      // Ignore .lock files explicitly
      if (filename.endsWith('.lock')) {
        print("[BackupService] Skipping lock file: $filename");
        continue;
      }

      // Optional: Strict mode - only allow expected box names
      // if (!_boxNames.any((name) => filename == '$name.hive')) continue;

      if (filename.endsWith('.hive')) {
        final targetPath = p.join(appDir.path, filename);
        print("[BackupService] Restoring $filename to $targetPath");

        final outputStream = OutputFileStream(targetPath);
        file.writeContent(outputStream);
        await outputStream.close();
        restoredCount++;
      }
    }

    if (restoredCount == 0) {
      throw Exception(
        "No se encontraron archivos de datos válidos (.hive) en el respaldo.",
      );
    }

    print("[BackupService] Restore completed. $restoredCount files restored.");
  }
}
