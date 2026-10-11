import 'package:flutter/material.dart';

import '../services/localization_service.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../widgets/design/cash_card.dart';
import 'business/business_gatekeeper.dart';
import 'info_screens.dart';
import 'loans/loans_gatekeeper.dart';
import 'settings_screen.dart';

/// Hub de funcionalidades secundarias.
///
/// Reúne las herramientas que antes vivían como pestañas o como FAB central
/// (Negocio, Préstamos, Configuración) junto con el acceso a Ayuda.
///
/// No contiene lógica de negocio: cada entrada conserva su gatekeeper de
/// licencia original (`BusinessGatekeeper`, `LoansGatekeeper`), por lo que los
/// chequeos de Art-Pay siguen aplicándose exactamente igual.
class MoreHubScreen extends StatelessWidget {
  const MoreHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final List<_HubEntry> entries = [
      _HubEntry(
        icon: Icons.storefront_outlined,
        label: context.t('nav_business'),
        destination: const BusinessGatekeeper(),
      ),
      _HubEntry(
        icon: Icons.real_estate_agent_outlined,
        label: context.t('nav_loans'),
        destination: const LoansGatekeeper(),
      ),
      _HubEntry(
        icon: Icons.settings_outlined,
        label: context.t('settings_title'),
        destination: const SettingsScreen(),
      ),
      _HubEntry(
        icon: Icons.help_outline,
        label: context.t('help_center'),
        destination: const HelpCenterScreen(),
      ),
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.screenVertical,
          AppSpacing.screenHorizontal,
          AppSpacing.xxxl,
        ),
        children: [
          Text(
            context.t('action_more'),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          CashCard(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < entries.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: AppSpacing.lg + 44 + AppSpacing.md,
                      color: theme.dividerColor,
                    ),
                  _HubTile(entry: entries[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de acceso a una herramienta del hub.
class _HubTile extends StatelessWidget {
  const _HubTile({required this.entry});

  final _HubEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      // CashCard pinta su superficie con un DecoratedBox: sin este Material el
      // ripple del ListTile quedaría oculto detrás de la tarjeta.
      type: MaterialType.transparency,
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => entry.destination),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        leading: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: AppRadius.radiusMd,
          ),
          child: Icon(entry.icon, size: 20, color: theme.colorScheme.primary),
        ),
        title: Text(entry.label, style: theme.textTheme.titleSmall),
        trailing: Icon(
          Icons.chevron_right,
          size: 20,
          color: theme.textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}

/// Destino de una entrada del hub.
class _HubEntry {
  const _HubEntry({
    required this.icon,
    required this.label,
    required this.destination,
  });

  final IconData icon;
  final String label;
  final Widget destination;
}