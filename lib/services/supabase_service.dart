import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'google_auth_service.dart';

/// Error de autenticación con un código estable para traducir en la interfaz.
///
/// El código evita mostrar mensajes técnicos de Supabase o de la red al
/// usuario: la pantalla decide qué texto enseñar según [code].
class SupabaseAuthException implements Exception {
  const SupabaseAuthException(this.code, [this.details]);

  /// `not_configured`, `offline`, `cancelled`, `auth` o `unknown`.
  final String code;

  /// Detalle técnico para los registros, nunca para la interfaz.
  final String? details;

  @override
  String toString() => 'SupabaseAuthException($code)';
}

/// Conexión de CashRápido con el backend de Supabase.
///
/// La app es local-first: los datos siguen viviendo en Hive y esta conexión es
/// la puerta de entrada a la nube (cuenta, respaldo y futuras sincronizaciones).
/// Por eso [initialize] nunca lanza: si no hay red o el servicio falla, la app
/// arranca igual y queda funcionando sin conexión.
///
/// El acceso es solo con la cuenta de Google: se pide el `idToken` al selector
/// nativo de Android (compartido con Google Drive) y Supabase lo verifica con
/// `signInWithIdToken`. No hay registro ni contraseña propios.
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
  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  /// Inicializa Supabase una sola vez.
  ///
  /// Devuelve `true` si la conexión quedó lista. La sesión se conserva entre
  /// arranques, así que el usuario no tiene que volver a iniciar sesión.
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

  /// Inicia sesión con la cuenta de Google elegida en el selector nativo.
  ///
  /// La misma sesión de Google queda disponible para Google Drive, así que el
  /// usuario autoriza una sola vez. Si Supabase no está inicializado (arranque
  /// sin red) se reintenta antes de pedir la cuenta.
  static Future<void> signInWithGoogle() async {
    if (!GoogleAuthService.isConfigured) {
      throw const SupabaseAuthException('not_configured');
    }
    if (!_initialized) {
      final bool ready = await initialize();
      if (!ready) throw SupabaseAuthException('offline', _lastError);
    }

    final GoogleAuthResult? google;
    try {
      google = await GoogleAuthService.signIn();
    } on GoogleAuthException catch (e) {
      throw SupabaseAuthException(e.code, e.details);
    }
    if (google == null) throw const SupabaseAuthException('cancelled');

    final String? idToken = google.idToken;
    if (idToken == null) {
      throw const SupabaseAuthException(
        'auth',
        'Google no devolvió un idToken (revisa GOOGLE_WEB_CLIENT_ID).',
      );
    }

    try {
      await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: google.accessToken,
      );
    } on AuthException catch (e) {
      throw SupabaseAuthException('auth', e.message);
    } catch (e) {
      throw SupabaseAuthException('unknown', e.toString());
    }
  }

  /// Cierra la sesión de la app y la de Google; los datos locales no se tocan.
  static Future<void> signOut() async {
    try {
      if (_initialized) {
        // Local: funciona también sin conexión y no depende del servidor.
        await client.auth.signOut(scope: SignOutScope.local);
      }
    } finally {
      await GoogleAuthService.signOut();
    }
  }

  static String _env(String key, String fallback) {
    if (!dotenv.isInitialized) return fallback;
    final String? value = dotenv.env[key];
    return value == null || value.trim().isEmpty ? fallback : value.trim();
  }
}
