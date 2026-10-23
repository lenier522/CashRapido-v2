import 'package:material_ui/material_ui.dart';

/// Colores oficiales de CashRapido.
///
/// La identidad visual gira alrededor de:
/// - Verde: crecimiento, dinero, progreso y acción.
/// - Verde oscuro: estabilidad y confianza.
/// - Fondo muy claro: sensación limpia y moderna.
/// - Fondo verde-negro: modo oscuro premium.
///
/// Evita definir colores directamente dentro de las pantallas.
/// Usa esta clase para mantener una identidad consistente.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // BRAND
  // ---------------------------------------------------------------------------

  /// Verde principal de CashRapido.
  static const Color primary = Color(0xFF18C96E);

  /// Verde principal más oscuro.
  static const Color primaryDark = Color(0xFF0FAE5B);

  /// Variante oscura para estados y elementos activos.
  static const Color primaryDeep = Color(0xFF087A40);

  /// Verde claro para fondos suaves, chips y estados seleccionados.
  static const Color primaryLight = Color(0xFFDDF8E9);

  /// Verde extremadamente suave.
  static const Color primarySurface = Color(0xFFEEFDF4);

  // ---------------------------------------------------------------------------
  // SECONDARY
  // ---------------------------------------------------------------------------

  /// Verde azulado secundario.
  static const Color secondary = Color(0xFF1FAF78);

  /// Variante secundaria oscura.
  static const Color secondaryDark = Color(0xFF14845C);

  /// Superficie secundaria clara.
  static const Color secondaryLight = Color(0xFFDDF6EC);

  // ---------------------------------------------------------------------------
  // NEUTRALS - LIGHT
  // ---------------------------------------------------------------------------

  /// Fondo general de la aplicación en modo claro.
  static const Color backgroundLight = Color(0xFFF7F9F8);

  /// Superficie principal.
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Superficie ligeramente elevada.
  static const Color surfaceVariantLight = Color(0xFFF0F4F2);

  /// Bordes sutiles.
  static const Color borderLight = Color(0xFFE1E8E4);

  /// Divider.
  static const Color dividerLight = Color(0xFFE7ECE9);

  /// Texto principal.
  static const Color textPrimary = Color(0xFF16201B);

  /// Texto secundario.
  static const Color textSecondary = Color(0xFF68756F);

  /// Texto terciario.
  static const Color textTertiary = Color(0xFF8D9993);

  /// Texto deshabilitado.
  static const Color textDisabled = Color(0xFFB3BCB7);

  // ---------------------------------------------------------------------------
  // NEUTRALS - DARK
  // ---------------------------------------------------------------------------

  /// Fondo general en modo oscuro.
  static const Color backgroundDark = Color(0xFF08110D);

  /// Superficie principal en dark mode.
  static const Color surfaceDark = Color(0xFF0D1913);

  /// Segunda superficie.
  static const Color surfaceDark2 = Color(0xFF13231B);

  /// Tercera superficie.
  static const Color surfaceDark3 = Color(0xFF192C22);

  /// Bordes en modo oscuro.
  static const Color borderDark = Color(0xFF24372E);

  /// Divider en modo oscuro.
  static const Color dividerDark = Color(0xFF203229);

  /// Texto principal dark.
  static const Color textPrimaryDark = Color(0xFFF2FFF7);

  /// Texto secundario dark.
  static const Color textSecondaryDark = Color(0xFFAAC0B4);

  /// Texto terciario dark.
  static const Color textTertiaryDark = Color(0xFF789086);

  /// Texto deshabilitado dark.
  static const Color textDisabledDark = Color(0xFF53665C);

  // ---------------------------------------------------------------------------
  // FINANCIAL SEMANTIC COLORS
  // ---------------------------------------------------------------------------

  /// Ingresos / dinero recibido.
  static const Color income = Color(0xFF16A765);

  /// Ingresos suaves.
  static const Color incomeLight = Color(0xFFE4F8ED);

  /// Gastos / dinero salido.
  static const Color expense = Color(0xFFE45757);

  /// Gastos suaves.
  static const Color expenseLight = Color(0xFFFDEAEA);

  /// Advertencia.
  static const Color warning = Color(0xFFF59E0B);

  /// Advertencia suave.
  static const Color warningLight = Color(0xFFFFF5DD);

  /// Error.
  static const Color error = Color(0xFFE5484D);

  /// Error suave.
  static const Color errorLight = Color(0xFFFDE8E9);

  /// Información.
  static const Color info = Color(0xFF3B82F6);

  /// Información suave.
  static const Color infoLight = Color(0xFFEAF2FF);

  // ---------------------------------------------------------------------------
  // EXTRA BRAND ACCENTS
  // ---------------------------------------------------------------------------

  static const Color orange = Color(0xFFFF7A1A);
  static const Color yellow = Color(0xFFF9C74F);
  static const Color blue = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);

  // ---------------------------------------------------------------------------
  // PERFIL (tarjeta destacada de Google Drive)
  // ---------------------------------------------------------------------------

  /// Verde lima brillante de la tarjeta principal de Perfil.
  ///
  /// Se añade como token de alcance controlado: sólo lo usa la tarjeta de
  /// Google Drive de Perfil, no cambia la identidad verde del resto de la app.
  static const Color lime = Color(0xFFCDF23F);

  /// Verde lima algo más oscuro para bordes o detalles sobre el lima.
  static const Color limeDeep = Color(0xFF9CC41F);

  /// Texto oscuro legible sobre [lime].
  static const Color onLime = Color(0xFF14210B);

  // ---------------------------------------------------------------------------
  // COMMON
  // ---------------------------------------------------------------------------

  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color transparent = Colors.transparent;

  // ---------------------------------------------------------------------------
  // GRADIENTS
  // ---------------------------------------------------------------------------

  /// Gradiente principal para elementos destacados.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  /// Gradiente más intenso para banners / hero cards.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1DDD7B), Color(0xFF0A9A4F), Color(0xFF087A40)],
  );

  /// Gradiente para modo oscuro.
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF123C29), Color(0xFF0A2116)],
  );
}
