import 'package:url_launcher/url_launcher.dart';

/// Punto único de configuración de los enlaces oficiales de CashRapido.
///
/// Centralizar aquí las direcciones evita repartir URLs por las pantallas y
/// deja en un solo sitio lo que todavía no está configurado: los enlaces con
/// valor `null` se muestran en la interfaz como «pendiente de configurar» en
/// lugar de abrir una dirección inventada.
///
/// Si en el futuro se habilita una red social o un documento legal, basta con
/// rellenar su campo aquí: la interfaz ya reacciona al valor real.
abstract final class OfficialLinks {
  // ---------------------------------------------------------------------------
  // COMUNIDAD Y REDES SOCIALES
  // ---------------------------------------------------------------------------

  /// Comunidad oficial de CashRapido (Telegram).
  static const String community = 'https://t.me/cashrapido26';

  /// Instagram oficial.
  static const String instagram = 'https://instagram.com/cashrapido23';

  /// Redes todavía no configuradas por el proyecto.
  ///
  /// Se declaran como `null` a propósito para que la interfaz muestre un
  /// estado de «enlace pendiente» en vez de un destino falso.
  static const String? discord = null;
  static const String? facebook = null;
  static const String? youtube = null;
  static const String? tiktok = null;

  // ---------------------------------------------------------------------------
  // SOPORTE
  // ---------------------------------------------------------------------------

  /// Correo oficial de soporte y contacto.
  static const String supportEmail = 'leniercruz02@gmail.com';

  // ---------------------------------------------------------------------------
  // TIENDAS Y DESCARGA
  // ---------------------------------------------------------------------------

  /// Ficha de la aplicación en Apklis (distribución principal en Cuba).
  static const String apklis =
      'https://apklis.cu/application/cu.lenier.cashrapido';

  /// Ficha de la aplicación en Google Play.
  static const String playStore =
      'https://play.google.com/store/apps/details?id=cu.lenier.cashrapido';

  /// Enlace de invitación/descarga que se comparte con otras personas.
  static const String invite = apklis;
}

/// Utilidades para abrir enlaces y correos de forma segura.
///
/// No lanzan excepciones al llamador: devuelven `false` cuando el enlace no se
/// pudo abrir, de modo que cada pantalla decide qué mensaje mostrar.
abstract final class LinkLauncher {
  /// Abre [url] en una aplicación externa.
  static Future<bool> open(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  /// Abre el cliente de correo con un mensaje preparado.
  static Future<bool> email({
    required String to,
    String? subject,
    String? body,
  }) async {
    final Map<String, String> params = <String, String>{};
    if (subject != null) params['subject'] = subject;
    if (body != null) params['body'] = body;

    final Uri uri = Uri(scheme: 'mailto', path: to, query: _encodeQuery(params));
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }
}
