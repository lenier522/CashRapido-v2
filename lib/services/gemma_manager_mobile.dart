import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';

class GemmaManager {
  static Future<void> initialize() async {
    await FlutterGemma.initialize();
  }

  static Future<void> installModel(String destPath) async {
    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
    ).fromFile(destPath).install();
  }
}
