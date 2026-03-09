class GemmaManager {
  static Future<void> initialize() async {
    // No-op on desktop
  }

  static Future<void> installModel(String destPath) async {
    throw Exception(
      "El modelo offline de Gemma no está soportado en la versión de Windows.",
    );
  }
}
