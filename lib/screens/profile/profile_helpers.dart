import 'package:flutter/material.dart';

import '../../licences/license_type.dart';
import '../../services/localization_service.dart';
import '../../services/official_links.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_snack.dart';
import '../licenses_screen.dart';

/// Utilidades compartidas por las pantallas de Perfil.
///
/// Evitan repetir en cada sección la navegación, el aviso de función bloqueada
/// y el manejo de enlaces externos.

/// Etiqueta legible del tipo de licencia del usuario.
///
/// Centraliza el mapeo de período y nivel para que ninguna pantalla repita la
/// misma tabla: «Gratis» para la licencia gratuita y «Período · Nivel» para el
/// resto («Mensual · Pro», «Anual · Empresarial»…).
String licenseLabel(BuildContext context, LicenseType type) {
  if (type == LicenseType.free) return context.t('license_free');
  final String period = switch (type.period) {
    LicensePeriod.weekly => context.t('license_period_weekly'),
    LicensePeriod.monthly => context.t('license_period_monthly'),
    LicensePeriod.annual => context.t('license_period_annual'),
    LicensePeriod.lifetime => context.t('license_free'),
  };
  final String level = switch (type.level) {
    LicenseLevel.personal => context.t('license_level_personal'),
    LicenseLevel.pro => context.t('license_level_pro'),
    LicenseLevel.enterprise => context.t('license_level_enterprise'),
    LicenseLevel.free => context.t('license_free'),
  };
  return '$period · $level';
}

/// Navega a [screen] con una ruta estándar.
Future<void> pushProfileScreen(BuildContext context, Widget screen) {
  return Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}

/// Muestra el aviso de función bloqueada con acceso a la pantalla de licencias.
void showFeatureLockedDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXxl),
      icon: const Icon(
        Icons.workspace_premium_outlined,
        color: AppColors.warning,
      ),
      title: Text(context.t('feature_locked_title')),
      content: Text(context.t('feature_locked_desc')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.t('close')),
        ),
        CashButton(
          label: context.t('upgrade_btn'),
          fullWidth: false,
          height: 44,
          icon: const Icon(Icons.workspace_premium_outlined, size: 18),
          onPressed: () {
            Navigator.pop(ctx);
            pushProfileScreen(context, const LicensesScreen());
          },
        ),
      ],
    ),
  );
}

/// Abre un enlace externo y avisa al usuario si no se pudo abrir.
Future<void> openOfficialLink(
  BuildContext context,
  String url, {
  String? failureMessage,
}) async {
  final bool ok = await LinkLauncher.open(url);
  if (!ok && context.mounted) {
    CashSnack.error(context, failureMessage ?? context.t('link_open_error'));
  }
}

/// Abre el cliente de correo y avisa si no se pudo.
Future<void> openOfficialEmail(
  BuildContext context, {
  required String to,
  String? subject,
  String? body,
}) async {
  final bool ok = await LinkLauncher.email(to: to, subject: subject, body: body);
  if (!ok && context.mounted) {
    CashSnack.error(context, context.t('link_open_error'));
  }
}

/// Avisa de que un enlace todavía no está configurado.
///
/// Se usa para las redes sociales cuya URL aún no existe en el proyecto: en
/// lugar de abrir un destino inventado, se explica el estado real.
void showPendingLinkDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXxl),
      icon: const Icon(Icons.link_off_rounded, color: AppColors.warning),
      title: Text(context.t('link_pending_title')),
      content: Text(context.t('link_pending_desc')),
      actions: [
        CashButton(
          label: context.t('close'),
          fullWidth: false,
          height: 44,
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}
