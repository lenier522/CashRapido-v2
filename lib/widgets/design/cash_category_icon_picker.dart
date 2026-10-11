import 'package:flutter/material.dart';

import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/category_icon_registry.dart';
import 'cash_chip.dart';
import 'cash_input.dart';

/// Selector de iconos de categoría.
///
/// Incluye búsqueda (por nombre, keywords y grupo), filtro por grupos y una
/// cuadrícula táctil con estado seleccionado inequívoco (borde + fondo tintado
/// + check). Es puramente presentacional: informa de [initialCodePoint] y
/// devuelve el nuevo `codePoint` de `Category.iconCode`.
///
/// El catálogo es estático ([CategoryIconRegistry.icons]); la búsqueda sólo
/// filtra la lista existente y nunca se recalcula en `build()`.
class CashCategoryIconPicker extends StatefulWidget {
  /// Código actualmente seleccionado.
  final int initialCodePoint;

  /// Devuelve el `codePoint` elegido.
  final ValueChanged<int> onSelected;

  const CashCategoryIconPicker({
    super.key,
    required this.initialCodePoint,
    required this.onSelected,
  });

  @override
  State<CashCategoryIconPicker> createState() => _CashCategoryIconPickerState();
}

class _CashCategoryIconPickerState extends State<CashCategoryIconPicker> {
  late final TextEditingController _searchController;
  String _query = '';
  String? _group; // null = todos los grupos

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CategoryIconOption> get _results {
    Iterable<CategoryIconOption> list = _group == null
        ? CategoryIconRegistry.icons
        : CategoryIconRegistry.byGroup(_group!);
    final String q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where(
        (option) =>
            option.name.toLowerCase().contains(q) ||
            option.keywords.any((k) => k.toLowerCase().contains(q)),
      );
    }
    return list.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final int columns = MediaQuery.sizeOf(context).width >= 500 ? 7 : 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CashInput(
          controller: _searchController,
          label: context.t('icon_search_hint'),
          hint: context.t('icon_search_hint'),
          prefix: const Icon(Icons.search_rounded),
          suffix: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Clear',
                ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              CashChip(
                label: context.t('icon_group_all'),
                selected: _group == null,
                onTap: () => setState(() => _group = null),
              ),
              for (final String group in CategoryIconGroups.groups) ...[
                const SizedBox(width: AppSpacing.xs),
                CashChip(
                  label: context.t(group),
                  selected: _group == group,
                  onTap: () => setState(() => _group = group),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text(
                    context.t('cat_no_icons'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  itemCount: _results.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: AppSpacing.xs,
                    crossAxisSpacing: AppSpacing.xs,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) => _IconTile(
                    option: _results[index],
                    isSelected:
                        _results[index].codePoint == widget.initialCodePoint,
                    onTap: () => widget.onSelected(_results[index].codePoint),
                  ),
                ),
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  final CategoryIconOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _IconTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10)
                : isDark
                ? AppColors.surfaceDark2
                : AppColors.surfaceVariantLight,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 1.8)
                : Border.all(color: Colors.transparent),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  option.icon,
                  size: 24,
                  color: isSelected
                      ? AppColors.primary
                      : isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
