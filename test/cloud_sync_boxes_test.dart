import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:cashrapido/models/models.dart';
import 'package:cashrapido/services/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('cloud_sync_boxes');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CategoryAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('la copia usa la caja abierta por el proveedor, no la reabre', () async {
    final Box<Category> box = await Hive.openBox<Category>('categories');
    await box.add(
      Category(id: 'c1', name: 'Comida', iconCode: 1, colorValue: 0xFF00AA55),
    );

    CloudSyncService.registerBoxes(<String, Box<dynamic>>{'categories': box});

    final Box<dynamic>? registered = CloudSyncService.boxFor('categories');
    expect(registered, isNotNull);
    expect(registered!.length, 1);
    expect((registered.values.first as Category).name, 'Comida');
    expect(CloudSyncService.boxFor('no_existe'), isNull);
  });
}
