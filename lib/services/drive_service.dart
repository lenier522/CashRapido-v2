import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart' as sign_in;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'backup_service.dart';

class DriveService {
  final sign_in.GoogleSignIn _googleSignIn = sign_in.GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  sign_in.GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
  Stream<sign_in.GoogleSignInAccount?> get onAuthStateChanged =>
      _googleSignIn.onCurrentUserChanged;

  final BackupService _backupService = BackupService();

  Future<sign_in.GoogleSignInAccount?> signInToGoogle() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      print('Sign in failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return null;
    return drive.DriveApi(client);
  }

  Future<void> backupData() async {
    final currentUser = _googleSignIn.currentUser;
    if (currentUser == null) {
      throw Exception("Debes iniciar sesión con Google.");
    }

    final api = await _getDriveApi();
    if (api == null) throw Exception("Error de conexión con Google Drive.");

    // 1. Generate Backup (Delegate to BackupService)
    File backupZip;
    try {
      backupZip = await _backupService.createBackup();
    } catch (e) {
      throw Exception("Error creando copia local para subir: $e");
    }

    // 2. Prepare Cloud Folder
    String? folderId = await _findOrCreateFolder(api, "CashRapido_Backups");
    if (folderId == null) {
      throw Exception("No se pudo crear la carpeta en Drive.");
    }

    // 3. Upload
    final media = drive.Media(backupZip.openRead(), backupZip.lengthSync());
    final driveFile = drive.File();
    driveFile.name =
        'cashrapido_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
    driveFile.parents = [folderId];

    await _cleanupOldBackups(api, folderId);
    await api.files.create(driveFile, uploadMedia: media);

    // 4. Cleanup Temp File
    if (backupZip.existsSync()) {
      backupZip.deleteSync();
    }
  }

  Future<void> restoreData() async {
    final currentUser = _googleSignIn.currentUser;
    if (currentUser == null) {
      throw Exception("Debes iniciar sesión con Google.");
    }

    final api = await _getDriveApi();
    if (api == null) throw Exception("Error de conexión con Google Drive.");

    // 1. Find Backup
    String? folderId = await _findFolder(api, "CashRapido_Backups");
    if (folderId == null) {
      throw Exception("No se encontró la carpeta de respaldos.");
    }

    final fileList = await api.files.list(
      q: "'$folderId' in parents and trashed = false",
      orderBy: "createdTime desc",
      pageSize: 1,
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      throw Exception("No se encontraron copias de seguridad en Drive.");
    }

    final backupDriveFile = fileList.files!.first;
    if (backupDriveFile.id == null) {
      throw Exception("Archivo de respaldo inválido.");
    }

    // 2. Download to Temp
    final media =
        await api.files.get(
              backupDriveFile.id!,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final appDir = await getApplicationDocumentsDirectory();
    final tempZipPath = p.join(appDir.path, 'temp_cloud_restore.zip');
    final tempZipFile = File(tempZipPath);

    final sink = tempZipFile.openWrite();
    await media.stream.pipe(sink);
    await sink.flush();
    await sink.close();

    // 3. Restore (Delegate to BackupService)
    try {
      await _backupService.restoreBackup(tempZipFile);
    } finally {
      if (tempZipFile.existsSync()) {
        tempZipFile.deleteSync();
      }
    }
  }

  // --- Helpers ---

  Future<String?> _findFolder(drive.DriveApi api, String name) async {
    final list = await api.files.list(
      q: "mimeType = 'application/vnd.google-apps.folder' and name = '$name' and trashed = false",
    );
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id;
    }
    return null;
  }

  Future<String?> _findOrCreateFolder(drive.DriveApi api, String name) async {
    String? id = await _findFolder(api, name);
    if (id != null) return id;

    final folder = drive.File();
    folder.name = name;
    folder.mimeType = 'application/vnd.google-apps.folder';

    final result = await api.files.create(folder);
    return result.id;
  }

  Future<void> _cleanupOldBackups(drive.DriveApi api, String folderId) async {
    final list = await api.files.list(
      q: "'$folderId' in parents and trashed = false",
      orderBy: "createdTime desc",
    );

    if (list.files != null && list.files!.length > 5) {
      for (int i = 5; i < list.files!.length; i++) {
        final fileId = list.files![i].id;
        if (fileId != null) {
          await api.files.delete(fileId);
        }
      }
    }
  }

  Future<DateTime?> getLastBackupDate() async {
    try {
      final api = await _getDriveApi();
      if (api == null) return null;

      String? folderId = await _findFolder(api, "CashRapido_Backups");
      if (folderId == null) return null;

      final fileList = await api.files.list(
        q: "'$folderId' in parents and trashed = false",
        orderBy: "createdTime desc",
        pageSize: 1,
        $fields: "files(createdTime)",
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.createdTime;
      }
    } catch (e) {
      print("Error getting last backup: $e");
    }
    return null;
  }
}
