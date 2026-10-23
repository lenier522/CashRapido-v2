import 'package:material_ui/material_ui.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/category_color_options.dart';

/// Selector de colores de categoría.
///
/// Presenta los 64 colores del catálogo único en una cuadrícula de 8 columnas.
/// Cada opción es táctil (>= 48 px) y el estado seleccionado es inequívoco:
/// anillo exterior, borde interno y check con contraste calculado. No guarda
/// estado ni decide nada: informa de [selected] y delega el cambio en
/// [onChanged].
///
/// El diseño interno admite añadir más tarde un color personalizado: basta
/// con añadir una ficha extra que abra el picker propio y pasar su resultado
/// por [onChanged], sin tocar la cuadrícula.
class CashCategoryColorPicker extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onChanged;

  const CashCategoryColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        const int columns = 8;
        final double tileSize =
            (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: CategoryColorOptions.colors.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
          ),
          itemBuilder: (context, index) {
            final Color color = CategoryColorOptions.colors[index];
            final bool isSelected = color == selected;
            return _ColorSwatch(
              color: color,
              isSelected: isSelected,
              tileSize: tileSize,
              isDark: isDark,
              onTap: () => onChanged(color),
            );
          },
        );
      },
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final double tileSize;
  final bool isDark;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.tileSize,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fore = CategoryColorOptions.contrastForeground(color);

    return Semantics(
      selected: isSelected,
      label: 'Color',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.all(isSelected ? 3 : 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? (isDark ? Colors.white24 : Colors.black12)
                  : Colors.transparent,
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: isSelected ? Border.all(color: color, width: 2) : null,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: tileSize * 0.45,
                      color: fore,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
