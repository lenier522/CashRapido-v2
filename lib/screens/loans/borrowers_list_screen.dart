import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/borrower.dart';
import '../../models/loan.dart';
import '../../providers/loan_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../utils/number_format_utils.dart';
import '../../widgets/design/cash_bottom_sheet.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_chip.dart';
import '../../widgets/design/cash_empty_state.dart';
import '../../widgets/design/cash_floating_button.dart';
import '../../widgets/design/cash_input.dart';
import '../../widgets/design/cash_section.dart';
import 'borrower_form_screen.dart';
import 'loan_detail_screen.dart';

/// Directorio de prestatarios (clientes).
///
/// Muestra el listado real de [Borrower] del [LoanProvider], permite buscar por
/// nombre, apellidos o teléfono (la misma búsqueda que ya existía) y abre la
/// ficha de la persona. No se añaden métricas nuevas ni se recalculan datos:
/// todo lo que se muestra proviene de los modelos existentes.
class BorrowersListScreen extends StatefulWidget {
  const BorrowersListScreen({super.key});

  @override
  State<BorrowersListScreen> createState() => _BorrowersListScreenState();
}

class _BorrowersListScreenState extends State<BorrowersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Misma lógica de filtrado que existía: nombre, apellidos o teléfono.
  List<Borrower> _applySearch(List<Borrower> borrowers) {
    if (_searchQuery.isEmpty) return borrowers;
    final query = _searchQuery.toLowerCase();
    return borrowers
        .where(
          (b) =>
              b.name.toLowerCase().contains(query) ||
              b.lastName.toLowerCase().contains(query) ||
              b.phone.contains(query),
        )
        .toList();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _openBorrowerForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BorrowerFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<LoanProvider>();

    final all = provider.borrowers;
    final filtered = _applySearch(all);
    final bool hasNoBorrowers = all.isEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(context.t('borrowers_title'))),
      body: Column(
        children: [
          _buildSearchField(context),
          if (!hasNoBorrowers) _buildCountLine(context, all.length),
          Expanded(
            child: hasNoBorrowers
                ? _buildEmptyBorrowers(context)
                : filtered.isEmpty
                ? _buildEmptyResults(context)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xs,
                      AppSpacing.xl,
                      96,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) =>
                        _buildBorrowerCard(context, filtered[i], provider),
                  ),
          ),
        ],
      ),
      // El botón de creación se oculta cuando no hay clientes porque el estado
      // vacío ya ofrece la misma acción (evita duplicarla).
      floatingActionButton: hasNoBorrowers
          ? null
          : CashFloatingButton(
              heroTag: 'borrowers_create_fab',
              icon: Icons.person_add_alt_1_rounded,
              label: context.t('borrower_new_client'),
              onPressed: () => _openBorrowerForm(context),
            ),
    );
  }

  // ──────────────────────────────────────────
  //   BÚSQUEDA Y CONTEO
  // ──────────────────────────────────────────
  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: CashInput(
        controller: _searchController,
        hint: context.t('borrowers_search_hint'),
        prefix: const Icon(Icons.search_rounded),
        suffix: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: context.t('close'),
                onPressed: _clearSearch,
              ),
        textInputAction: TextInputAction.search,
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  Widget _buildCountLine(BuildContext context, int count) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.people_alt_outlined, size: 16, color: secondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '${context.t('total')}: $count',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //   LISTADO
  // ──────────────────────────────────────────
  Widget _buildBorrowerCard(
    BuildContext context,
    Borrower borrower,
    LoanProvider provider,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final risk = _riskStyle(context, borrower.riskLevel);
    final hasAddress = borrower.address.trim().isNotEmpty;

    return CashCard(
      onTap: () => _showBorrowerDetails(context, borrower, provider),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          _BorrowerAvatar(borrower: borrower),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Identidad principal.
                Text(
                  borrower.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _InfoLine(
                  icon: Icons.phone_rounded,
                  text: borrower.phone,
                  color: secondary,
                ),
                if (hasAddress) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  _InfoLine(
                    icon: Icons.location_on_outlined,
                    text: borrower.address,
                    color: secondary,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: CashChip(
                    label: risk.label,
                    icon: risk.icon,
                    color: risk.color,
                    selected: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right_rounded, color: secondary),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //   ESTADOS VACÍOS
  // ──────────────────────────────────────────
  Widget _buildEmptyBorrowers(BuildContext context) {
    return CashEmptyState(
      icon: Icons.people_outline_rounded,
      title: context.t('borrowers_empty_title'),
      message: context.t('borrowers_empty_desc'),
      buttonLabel: context.t('borrower_new_client'),
      onButtonPressed: () => _openBorrowerForm(context),
    );
  }

  Widget _buildEmptyResults(BuildContext context) {
    return CashEmptyState(
      icon: Icons.search_off_rounded,
      title: context.t('no_search_results'),
      // Una sola acción devuelve al listado completo.
      action: TextButton.icon(
        onPressed: _clearSearch,
        icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
        label: Text(context.t('filter_all')),
      ),
    );
  }

  // ──────────────────────────────────────────
  //   FICHA DEL PRESTATARIO (detalle)
  // ──────────────────────────────────────────
  void _showBorrowerDetails(
    BuildContext context,
    Borrower borrower,
    LoanProvider provider,
  ) {
    final regDate =
        '${borrower.registrationDate.day}/${borrower.registrationDate.month}/${borrower.registrationDate.year}';

    CashBottomSheet.show(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: borrower.fullName,
        subtitle: '${context.t('borrower_registered_on')} $regDate',
        trailing: _BorrowerAvatar(borrower: borrower, radius: 24),
        child: _buildDetailsBody(sheetContext, borrower, provider),
      ),
    );
  }

  Widget _buildDetailsBody(
    BuildContext sheetContext,
    Borrower borrower,
    LoanProvider provider,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final risk = _riskStyle(context, borrower.riskLevel);

    final hasLocation = borrower.writtenLocation?.trim().isNotEmpty ?? false;
    final hasRef = borrower.personalReference?.trim().isNotEmpty ?? false;
    final hasNotes = borrower.notes?.trim().isNotEmpty ?? false;
    final hasExtra = hasLocation || hasRef || hasNotes;

    // Los préstamos se relacionan por el identificador estable `borrowerId`.
    // No se consulta de nuevo el almacenamiento ni se recalculan saldos: se
    // leen los préstamos ya cargados en el provider.
    final relatedLoans =
        provider.loans.where((l) => l.borrowerId == borrower.id).toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: CashChip(
            label: risk.label,
            icon: risk.icon,
            color: risk.color,
            selected: true,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        CashSection(
          title: context.t('borrower_basic_info'),
          child: Column(
            children: [
              _DetailTile(
                icon: Icons.phone_android_rounded,
                label: context.t('borrower_phone_label'),
                value: borrower.phone,
              ),
              _DetailTile(
                icon: Icons.home_rounded,
                label: context.t('borrower_address_label'),
                value: borrower.address,
              ),
            ],
          ),
        ),

        if (hasExtra) ...[
          const SizedBox(height: AppSpacing.xl),
          CashSection(
            title: context.t('borrower_additional_info'),
            child: Column(
              children: [
                if (hasLocation)
                  _DetailTile(
                    icon: Icons.map_outlined,
                    label: context.t('borrower_location_label'),
                    value: borrower.writtenLocation!,
                  ),
                if (hasRef)
                  _DetailTile(
                    icon: Icons.people_outline_rounded,
                    label: context.t('borrower_personal_ref_label'),
                    value: borrower.personalReference!,
                  ),
                if (hasNotes)
                  _DetailTile(
                    icon: Icons.notes_rounded,
                    label: context.t('borrower_notes_label'),
                    value: borrower.notes!,
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        CashSection(
          title: context.t('nav_loans'),
          child: relatedLoans.isEmpty
              ? Text(
                  context.t('no_loans_title'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: secondary,
                  ),
                )
              : Column(
                  children: [
                    for (final loan in relatedLoans)
                      _RelatedLoanTile(
                        loan: loan,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoanDetailScreen(loan: loan),
                            ),
                          );
                        },
                      ),
                  ],
                ),
        ),

        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(
              child: CashButton(
                label: context.t('borrower_edit'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                type: CashButtonType.secondary,
                height: 48,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BorrowerFormScreen(borrower: borrower),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: CashButton(
                label: context.t('borrower_delete'),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                type: CashButtonType.danger,
                height: 48,
                onPressed: () =>
                    _confirmDeleteBorrower(sheetContext, borrower, provider),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmDeleteBorrower(
    BuildContext sheetContext,
    Borrower borrower,
    LoanProvider provider,
  ) {
    // Se conserva el flujo existente: sólo se elimina el prestatario, previa
    // confirmación. No se tocan los préstamos ni sus relaciones.
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('borrower_delete_title')),
        content: Text(
          context.t('borrower_delete_desc').replaceAll(
            '{name}',
            borrower.fullName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('cancel')),
          ),
          CashButton(
            label: context.t('borrower_delete'),
            type: CashButtonType.danger,
            fullWidth: false,
            height: 46,
            onPressed: () async {
              await provider.deleteBorrower(borrower.id);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//   COMPONENTES AUXILIARES
// ─────────────────────────────────────────────

/// Avatar del prestatario: usa la foto local si existe; si no, muestra las
/// iniciales derivadas del nombre real. No inventa imágenes ni datos.
class _BorrowerAvatar extends StatelessWidget {
  final Borrower borrower;
  final double radius;

  const _BorrowerAvatar({required this.borrower, this.radius = 26});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = borrower.localPhotoPath;
    final bool hasPhoto =
        path != null && path.isNotEmpty && File(path).existsSync();

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: hasPhoto ? FileImage(File(path)) : null,
      child: hasPhoto
          ? null
          : Text(
              _initials(borrower.fullName),
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.78,
              ),
            ),
    );
  }
}

/// Línea secundaria compacta (icono + texto) que nunca desborda: el texto se
/// recorta con puntos suspensivos dentro de su fila.
class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoLine({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Par etiqueta/valor de la ficha. El valor se ajusta en varias líneas para no
/// recortar direcciones, referencias o notas.
class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: secondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: secondary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila compacta de un préstamo relacionado. Sólo lectura: identificador,
/// importe de capital almacenado y estado real. Al pulsar abre el detalle
/// existente del préstamo.
class _RelatedLoanTile extends StatelessWidget {
  final Loan loan;
  final VoidCallback onTap;

  const _RelatedLoanTile({required this.loan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final status = _loanStatusStyle(context, loan.status, isDark);

    return CashCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      boxShadow: isDark ? AppShadows.darkSoft : AppShadows.soft,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${loan.amount.toFormattedString(2)} ${loan.currency}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '#${_shortId(loan.id)} · ${context.t('loan_card_principal')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Ancho acotado para que el estado nunca desplace al importe ni
          // desborde en pantallas estrechas; el texto se recorta si es largo.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 128),
            child: _MiniStatusChip(label: status.label, color: status.color),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded, size: 18, color: secondary),
        ],
      ),
    );
  }
}

/// Insignia de estado compacta con color explícito.
class _MiniStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniStatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//   HELPERS
// ─────────────────────────────────────────────

/// Iniciales a partir del nombre real (nombre + primer apellido).
String _initials(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final first = parts.first.trim();
  final last = parts.length > 1 ? parts.last.trim() : '';
  final initials =
      '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}';
  return initials.isEmpty ? '?' : initials.toUpperCase();
}

String _shortId(String id) => id.length > 8 ? id.substring(0, 8) : id;

_RiskStyle _riskStyle(BuildContext context, String level) {
  switch (level) {
    case 'high':
      return _RiskStyle(
        AppColors.error,
        context.t('borrower_list_risk_high'),
        Icons.error_outline_rounded,
      );
    case 'medium':
      return _RiskStyle(
        AppColors.warning,
        context.t('borrower_list_risk_medium'),
        Icons.warning_amber_rounded,
      );
    case 'low':
    default:
      return _RiskStyle(
        AppColors.income,
        context.t('borrower_list_risk_low'),
        Icons.verified_outlined,
      );
  }
}

_StatusStyle _loanStatusStyle(BuildContext context, String status, bool isDark) {
  switch (status) {
    case 'paid':
      return _StatusStyle(AppColors.income, context.t('loan_status_paid'));
    case 'overdue':
      return _StatusStyle(AppColors.error, context.t('loan_status_overdue'));
    case 'written_off':
      return _StatusStyle(
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        context.t('loan_status_written_off'),
      );
    case 'refinanced':
      return _StatusStyle(AppColors.info, context.t('loan_status_refinanced'));
    case 'active':
    default:
      return _StatusStyle(AppColors.primary, context.t('loan_status_active'));
  }
}

// ─────────────────────────────────────────────
//   MODELOS PRIVADOS
// ─────────────────────────────────────────────

class _RiskStyle {
  final Color color;
  final String label;
  final IconData icon;

  const _RiskStyle(this.color, this.label, this.icon);
}

class _StatusStyle {
  final Color color;
  final String label;

  const _StatusStyle(this.color, this.label);
}
