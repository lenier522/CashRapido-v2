import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Error del acceso con Google con un código estable para traducir en la UI.
class GoogleAuthException implements Exception {
  const GoogleAuthException(this.code, [this.details]);

  /// `not_configured`, `cancelled` o `failed`.
  final String code;
  final String? details;

  @override
  String toString() => 'GoogleAuthException($code)';
}

/// Resultado de un acceso con Google: la cuenta y los tokens que Supabase
/// necesita para crear la sesión.
class GoogleAuthResult {
  const GoogleAuthResult({
    required this.account,
    this.idToken,
    this.accessToken,
  });

  final GoogleSignInAccount account;
  final String? idToken;
  final String? accessToken;
}

/// Única sesión de Google de la app.
///
/// Se usa para las dos cosas que dependen de la cuenta: el acceso a CashRápido
/// (Supabase valida el `idToken`) y el respaldo en Google Drive (los mismos
/// permisos). No hay un segundo inicio de sesión para Drive.
///
/// Pide el selector nativo de cuentas de Android (`google_sign_in`), no un
/// navegador. Necesita el Client ID **Web** en `GOOGLE_WEB_CLIENT_ID`: Google
/// emite el `idToken` con esa audiencia y Supabase lo verifica.
abstract final class GoogleAuthService {
  static const List<String> _scopes = <String>[
    'email',
    drive.DriveApi.driveFileScope,
  ];

  static GoogleSignIn? _signIn;

  /// Client ID Web de Google Cloud, leído de `.env`.
  static String? get webClientId {
    if (!dotenv.isInitialized) return null;
    final String? value = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// `true` si la build trae el Client ID Web necesario.
  static bool get isConfigured => webClientId != null;

  /// Cuenta con sesión en memoria, si la hay.
  static GoogleSignInAccount? get currentUser => _signIn?.currentUser;

  static GoogleSignIn _client() {
    final String? id = webClientId;
    if (id == null) throw const GoogleAuthException('not_configured');
    return _signIn ??= GoogleSignIn(scopes: _scopes, serverClientId: id);
  }

  /// Abre el selector nativo de cuentas y devuelve los tokens de Google.
  ///
  /// Devuelve `null` si el usuario cancela.
  static Future<GoogleAuthResult?> signIn() async {
    final GoogleSignIn client = _client();

    try {
      final GoogleSignInAccount? account = await client.signIn();
      if (account == null) return null;
      return await _withTokens(account);
    } on PlatformException catch (e) {
      if (e.code.toLowerCase().contains('cancel')) {
        throw const GoogleAuthException('cancelled');
      }
      throw GoogleAuthException('failed', e.message);
    } on GoogleAuthException {
      rethrow;
    } catch (e) {
      throw GoogleAuthException('failed', e.toString());
    }
  }

  /// Reconoce la cuenta ya autorizada sin mostrar ninguna interfaz.
  ///
  /// Es lo que mantiene viva la sesión de Drive al reabrir la app. Devuelve
  /// `null` si no hay autorización previa o no hay red.
  static Future<GoogleAuthResult?> signInSilently() async {
    if (!isConfigured) return null;

    try {
      final GoogleSignInAccount? account = await _client().signInSilently();
      if (account == null) return null;
      return await _withTokens(account);
    } catch (e) {
      if (kDebugMode) debugPrint('Google silent sign-in: $e');
      return null;
    }
  }

  /// Cliente autenticado para las APIs de Google (Google Drive).
  ///
  /// Reutiliza la sesión ya autorizada; `google_sign_in` refresca el token
  /// solo cuando hace falta.
  static Future<http.Client?> authenticatedClient() async {
    if (!isConfigured) return null;
    try {
      return await _client().authenticatedClient();
    } catch (e) {
      if (kDebugMode) debugPrint('Google auth client: $e');
      return null;
    }
  }

  /// Cierra la sesión local de Google sin revocar el permiso concedido.
  static Future<void> signOut() async {
    await _signIn?.signOut();
  }

  static Future<GoogleAuthResult> _withTokens(
    GoogleSignInAccount account,
  ) async {
    final GoogleSignInAuthentication auth = await account.authentication;
    return GoogleAuthResult(
      account: account,
      idToken: auth.idToken,
      accessToken: auth.accessToken,
    );
  }
}
