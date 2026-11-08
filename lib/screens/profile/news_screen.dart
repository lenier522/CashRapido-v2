import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/app_info.dart';
import '../../services/changelog_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_card.dart';

/// Apartado «Novedades».
///
/// Muestra todas las versiones con sus cambios, leídas de `assets/CHANGELOG.md`.
/// La versión actual aparece destacada en la parte superior.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<ChangelogEntry>? _entries;

  @override
  void initState() {
    super.initState();
    ChangelogService.load().then((e) {
      if (mounted) setState(() => _entries = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('community_news')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _entries == null
          ? const Center(child: CircularProgressIndicator())
          : _entries!.isEmpty
              ? _buildEmpty(context, secondary)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                    vertical: AppSpacing.screenVertical,
                  ),
                  itemCount: _entries!.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) =>
                      _VersionCard(entry: _entries![index]),
                ),
    );
  }

  Widget _buildEmpty(BuildContext context, Color secondary) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.screenVertical,
      ),
      children: [
        CashCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Icon(Icons.new_releases_rounded, size: 44,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text(AppInfo.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${context.t('news_version_label')}: ${AppInfo.fullVersion}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: secondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.t('news_no_changelog'),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: secondary),
        ),
      ],
    );
  }
}

/// Tarjeta de una versión con su lista de cambios.
class _VersionCard extends StatelessWidget {
  const _VersionCard({required this.entry});

  final ChangelogEntry entry;

  bool get _isCurrent => entry.version == AppInfo.version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color primary = theme.colorScheme.primary;
    final Color secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return CashCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: _isCurrent
                      ? primary.withValues(alpha: 0.12)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06)),
                  borderRadius: AppRadius.radiusSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isCurrent) ...[
                      Icon(Icons.new_releases_rounded,
                          size: 13, color: primary),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      'v${entry.version}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: _isCurrent ? primary : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isCurrent) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.radiusSm,
                  ),
                  child: Text(
                    'Actual',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                _formatDate(entry.date),
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
            ],
          ),

          if (entry.changes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),

            // ── Lista de cambios ───────────────────────────────────────────
            ...entry.changes.map(
              (change) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        change,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('d MMM yyyy', 'es').format(date);
  }
}
