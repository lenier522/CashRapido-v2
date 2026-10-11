import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Entrada de importe pensada para ser el elemento más importante de un
/// formulario financiero: cifra grande, centrada y teñida con el color
/// semántico del movimiento (gasto / ingreso).
///
/// No aplica ningún formato: el texto es exactamente el que escribe el
/// usuario y lo interpreta cada pantalla con las utilidades de número ya
/// existentes en el proyecto.
class CashAmountInput extends StatelessWidget {
  final TextEditingController controller;

  /// Etiqueta pequeña sobre la cifra.
  final String label;

  /// Símbolo de la moneda mostrado a la izquierda de la cifra.
  final String symbol;

  /// Código de la moneda mostrado como ayuda bajo la cifra.
  final String? code;

  /// `true` para gastos: cifra en `AppColors.expense`. `false` para ingresos.
  final bool isExpense;

  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final String? hintText;
  final bool autofocus;
  final double fontSize;
  final bool compact;

  const CashAmountInput({
    super.key,
    required this.controller,
    required this.label,
    this.symbol = '',
    this.code,
    this.isExpense = true,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.errorText,
    this.hintText = '0.00',
    this.autofocus = false,
    this.fontSize = 40,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color semantic = isExpense ? AppColors.expense : AppColors.income;
    final Color secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final bool hasError = errorText != null && errorText!.isNotEmpty;
    final bool isEmpty = controller.text.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: secondaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark2
                : AppColors.surfaceVariantLight,
            borderRadius: AppRadius.radiusXl,
            border: Border.all(
              color: hasError
                  ? AppColors.error
                  : isEmpty
                  ? (isDark ? AppColors.borderDark : AppColors.borderLight)
                  : semantic.withValues(alpha: 0.45),
              width: hasError ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (symbol.isNotEmpty) ...[
                Text(
                  symbol,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isEmpty ? secondaryColor : semantic,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              // `Expanded` en lugar de `IntrinsicWidth`: mantiene el cursor
              // centrado y deja que el campo ceda espacio al símbolo sin
              // desbordarse con textos largos o escala de fuente grande.
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: autofocus,
                  keyboardType: keyboardType,
                  textInputAction: textInputAction,
                  textAlign: TextAlign.center,
                  onChanged: onChanged,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: fontSize,
                    color: isEmpty ? secondaryColor : semantic,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    hintText: hintText,
                    hintStyle: Theme.of(context).textTheme.displaySmall
                        ?.copyWith(
                          fontSize: fontSize,
                          color: secondaryColor,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (code != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            code!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: secondaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (hasError) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 16, color: AppColors.error),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  errorText!,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
