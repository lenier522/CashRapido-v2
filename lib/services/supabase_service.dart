import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Conexión de CashRápido con el backend de Supabase.
///
/// La app es local-first: los datos siguen viviendo en Hive y esta conexión es
/// la puerta de entrada a la nube (cuentas, respaldo y futuras sincronizaciones).
/// Por eso [initialize] nunca lanza: si no hay red o el servicio falla, la app
/// arranca igual y queda funcionando sin conexión.
///
/// Las credenciales se pueden sobrescribir desde `.env` con `SUPABASE_URL` y
/// `SUPABASE_PUBLISHABLE_KEY`; si no existen se usan las del proyecto.
abstract final class SupabaseService {
  static const String _defaultUrl = 'https://oahkexkjvtsbaowfxzis.supabase.co';
  static const String _defaultKey =
      'sb_publishable_t5LFFleUT4PQSS375IEmjA_677zxDpc';

  static bool _initialized = false;
  static String? _lastError;

  /// URL del proyecto de Supabase.
  static String get url => _env('SUPABASE_URL', _defaultUrl);

  /// Clave pública (publishable) del proyecto.
  static String get publishableKey =>
      _env('SUPABASE_PUBLISHABLE_KEY', _defaultKey);

  /// `true` cuando [initialize] completó la conexión con el backend.
  static bool get isInitialized => _initialized;

  /// Último error de inicialización, para diagnóstico.
  static String? get lastError => _lastError;

  /// Cliente de Supabase. Solo debe usarse si [isInitialized] es `true`.
  static SupabaseClient get client => Supabase.instance.client;

  /// Sesión activa, o `null` si el usuario no ha iniciado sesión.
  static Session? get currentSession {
    if (!_initialized) return null;
    return client.auth.currentSession;
  }

  /// Usuario autenticado, o `null` si no hay sesión.
  static User? get currentUser => currentSession?.user;

  /// `true` si hay una sesión de Supabase activa.
  static bool get isSignedIn => currentSession != null;

  /// Cambios de sesión (inicio, renovación y cierre) emitidos por Supabase.
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// Inicializa Supabase una sola vez.
  ///
  /// Devuelve `true` si la conexión quedó lista. La sesión se conserva entre
  /// arranques, así que el usuario no tiene que volver a autenticarse.
  static Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      await Supabase.initialize(url: url, publishableKey: publishableKey);
      _initialized = true;
      _lastError = null;
      return true;
    } catch (e) {
      _initialized = false;
      _lastError = e.toString();
      debugPrint('Supabase no disponible: $e');
      return false;
    }
  }

  /// Comprueba que el backend responde (útil para avisos de sin conexión).
  static Future<bool> checkConnection({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final http.Response response = await http
          .get(
            Uri.parse('$url/auth/v1/health'),
            headers: <String, String>{'apikey': publishableKey},
          )
          .timeout(timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Inicia sesión con correo y contraseña.
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  /// Crea una cuenta con correo y contraseña.
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return client.auth.signUp(email: email, password: password);
  }

  /// Cierra la sesión actual; los datos locales no se tocan.
  static Future<void> signOut() => client.auth.signOut();

  static String _env(String key, String fallback) {
    if (!dotenv.isInitialized) return fallback;
    final String? value = dotenv.env[key];
    return value == null || value.trim().isEmpty ? fallback : value.trim();
  }
}
