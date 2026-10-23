import 'package:material_ui/material_ui.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../utils/number_format_utils.dart';
import '../widgets/design/cash_bottom_sheet.dart';
import '../widgets/design/cash_button.dart';
import '../widgets/design/cash_card.dart';
import '../widgets/design/cash_chip.dart';
import '../widgets/design/cash_empty_state.dart';
import '../widgets/design/cash_icon_button.dart';
import '../widgets/design/cash_selector_field.dart';

/// Lectura de confirmaciones de Transfermóvil.
///
/// El motor es intocable: permiso de SMS, consulta a `PAGOxMOVIL`, los cuatro
/// patrones de texto, el cálculo de descuentos, la detección de movimiento ya
/// registrado y la llamada a `addTransaction` se mantienen exactamente igual.
/// Sólo cambia la presentación: tarjetas del design system, estados vacíos y un
/// diálogo de confirmación coherente con el resto de formularios.
class TransferMovilScreen extends StatefulWidget {
  const TransferMovilScreen({super.key});

  @override
  State<TransferMovilScreen> createState() => _TransferMovilScreenState();
}

class _TransferMovilScreenState extends State<TransferMovilScreen> {
  final SmsQuery _query = SmsQuery();
  bool _isLoading = false;
  bool _isRegistering = false;
  List<SmsMessage> _messages = [];
  PermissionStatus? _permissionStatus;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndScan();
  }

  Future<void> _checkPermissionAndScan() async {
    setState(() => _isLoading = true);

    var status = await Permission.sms.status;

    if (!status.isGranted) {
      status = await Permission.sms.request();
    }

    if (!mounted) return;

    setState(() {
      _permissionStatus = status;
    });

    if (status.isGranted) {
      await _scanSMS();
    } else if (status.isPermanentlyDenied) {
      setState(() => _isLoading = false);
      _showPermissionDialog();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        icon: const Icon(Icons.sms_outlined, color: AppColors.warning),
        title: Text(
          "Permiso necesario",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: Text(
          "Para leer las confirmaciones de pago, necesitamos acceso a tus SMS. "
          "Por favor habilita el permiso en la configuración.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('cancel')),
          ),
          CashButton(
            label: "Abrir Configuración",
            fullWidth: false,
            height: 44,
            onPressed: () {
              Navigator.pop(dialogContext);
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _scanSMS() async {
    // Assumes permission is already granted or we are retrying
    if (_permissionStatus != null && !_permissionStatus!.isGranted) {
      // Double check in case user went to settings and came back
      var status = await Permission.sms.status;
      if (!mounted) return;
      setState(() {
        _permissionStatus = status;
      });
      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          _showPermissionDialog();
        } else {
          final newStatus = await Permission.sms.request();
          if (!mounted) return;
          setState(() => _permissionStatus = newStatus);
          if (!newStatus.isGranted) return;
        }
        if (!_permissionStatus!.isGranted) return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        address: "PAGOxMOVIL",
      );

      final validMessages = messages.where((sms) {
        final body = sms.body ?? "";
        return body.contains("La Transferencia fue completada") ||
            body.contains("Se ha realizado una transferencia a la cuenta") ||
            body.contains("Pago completado") ||
            body.contains("factura de electricidad fue completado");
      }).toList();

      if (!mounted) return;
      setState(() {
        _messages = validMessages;
      });
    } catch (e) {
      debugPrint("Error querying SMS: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al leer SMS: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If permission is explicitly denied/restricted, show specific UI
    if (_permissionStatus != null && !_permissionStatus!.isGranted) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(showRefresh: false),
        body: CashEmptyState(
          icon: Icons.sms_failed_outlined,
          title: "Permiso Requerido",
          message:
              "No podemos leer tus mensajes para importar transacciones sin tu permiso.",
          buttonLabel: _permissionStatus!.isPermanentlyDenied
              ? "Abrir Configuración"
              : "Conceder Permiso",
          onButtonPressed: () async {
            if (_permissionStatus!.isPermanentlyDenied) {
              openAppSettings();
            } else {
              _checkPermissionAndScan();
            }
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(showRefresh: true),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _messages.isEmpty
          ? const CashEmptyState(
              icon: Icons.smartphone_outlined,
              title: "No se encontraron transferencias",
              message: "Tus pagos de Transfermóvil aparecerán aquí",
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _checkPermissionAndScan,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.md,
                  AppSpacing.screenHorizontal,
                  AppSpacing.xxxl,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final sms = _messages[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _buildMessageCard(context, sms),
                  );
                },
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar({required bool showRefresh}) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        "Transfermóvil",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      actions: [
        if (showRefresh)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: CashIconButton(
              icon: Icons.refresh_rounded,
              size: 42,
              bordered: true,
              onPressed: _isLoading ? null : _checkPermissionAndScan,
            ),
          ),
      ],
    );
  }

  Widget _buildMessageCard(BuildContext context, SmsMessage sms) {
    final provider = Provider.of<AppProvider>(context);
    final body = sms.body ?? "";
    final date = sms.date ?? DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine Type & Amount
    bool isIncome = body.contains(
      "Se ha realizado una transferencia a la cuenta",
    );
    bool isPayment = body.contains("Pago completado");
    bool isElectricityBill = body.contains(
      "factura de electricidad fue completado",
    );

    double amount = 0.0;
    String otherParty = "";
    double discountPercent = 0.0;

    if (isIncome) {
      final match = RegExp(r"de\s*([\d\.]+)\s*CUP").firstMatch(body);
      amount = double.tryParse(match?.group(1) ?? "0") ?? 0.0;
      final accMatch = RegExp(r"cuenta\s*(\d+)").firstMatch(body);
      if (accMatch != null) {
        otherParty =
            "Cuenta ...${accMatch.group(1)?.substring(accMatch.group(1)!.length - 4)}";
      }
    } else if (isElectricityBill) {
      // Logic for electricity bill payment
      // Use "Importe Pagado" as the amount to register (per user request)
      double invoiceAmount = 0.0;

      final paidMatch = RegExp(
        r"Importe\s+Pagado:?\s*([\d\.]+)\s*CUP",
        caseSensitive: false,
      ).firstMatch(body);
      if (paidMatch != null) {
        amount = double.tryParse(paidMatch.group(1) ?? "0") ?? 0.0;
      }

      final invoiceMatch = RegExp(
        r"Importe\s+Factura:?\s*([\d\.]+)\s*CUP",
        caseSensitive: false,
      ).firstMatch(body);
      if (invoiceMatch != null) {
        invoiceAmount = double.tryParse(invoiceMatch.group(1) ?? "0") ?? 0.0;
        if (amount > 0 && invoiceAmount > 0 && invoiceAmount > amount) {
          discountPercent = ((invoiceAmount - amount) / invoiceAmount) * 100;
        }
      }

      otherParty = "A: Factura Electricidad";
    } else if (isPayment) {
      // Logic for "Pago completado"
      double originalAmount = 0.0;

      final originalMatch = RegExp(
        r"(?:[Ii]mporte|imorte):?\s*([\d\.]+)\s*CUP",
      ).firstMatch(body);
      if (originalMatch != null) {
        originalAmount = double.tryParse(originalMatch.group(1) ?? "0") ?? 0.0;
      }

      final paidMatch = RegExp(
        r"Importe [Pp]agado:?\s*([\d\.]+)\s*CUP",
      ).firstMatch(body);
      if (paidMatch != null) {
        amount = double.tryParse(paidMatch.group(1) ?? "0") ?? 0.0;
        if (originalAmount > 0 && originalAmount > amount) {
          discountPercent = ((originalAmount - amount) / originalAmount) * 100;
        }
      } else {
        amount = originalAmount;
      }

      final entityMatch = RegExp(
        r"Entidad:\s*(.*?)(?=\s+id\s+compra|\s+imorte|\s+Importe|$)",
        caseSensitive: false,
      ).firstMatch(body);
      final storeMatch = RegExp(
        "Tienda Virtual ETECSA",
        caseSensitive: false,
      ).hasMatch(body);

      if (entityMatch != null && entityMatch.group(1)!.trim().isNotEmpty) {
        otherParty = "A: ${entityMatch.group(1)!.trim()}";
      } else if (storeMatch) {
        otherParty = "A: Tienda Virtual ETECSA";
      } else {
        otherParty = "Pago de Servicio";
      }
    } else {
      // Logic for Standard Transfer Sent
      final match = RegExp(r"Monto:\s*([\d\.]+)").firstMatch(body);
      amount = double.tryParse(match?.group(1) ?? "0") ?? 0.0;
      final benMatch = RegExp(r"Beneficiario:\s*(\S+)").firstMatch(body);
      if (benMatch != null) otherParty = "A: ${benMatch.group(1)}";
    }

    bool isRegistered = provider.transactions.any((t) {
      if (t.categoryId != 'cat_transfermovil') return false;
      final targetAmount = isIncome ? amount : -amount;
      if (t.amount.toFormattedString(2) != targetAmount.toFormattedString(2)) {
        return false;
      }
      return t.date.difference(date).inSeconds.abs() < 60;
    });

    final Color accent = isIncome ? AppColors.income : AppColors.expense;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return CashCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      border: Border.all(color: accent.withValues(alpha: isDark ? 0.35 : 0.22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isIncome
                          ? "Transferencia Recibida"
                          : isElectricityBill
                          ? "Pago Factura Electricidad"
                          : "Transferencia Enviada",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      "${date.day}/${date.month}/${date.year} • "
                      "${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              if (isRegistered) ...[
                const SizedBox(width: AppSpacing.sm),
                CashChip(
                  label: "Registrado",
                  icon: Icons.check_rounded,
                  color: AppColors.income,
                  selected: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Monto · CUP",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: secondary),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${isIncome ? '+' : '-'}\$${amount.toFormattedString(2)}',
                        maxLines: 1,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              if (discountPercent > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                CashChip(
                  label:
                      '-${discountPercent.toFormattedString(1).replaceAll('.0', '')}%',
                  icon: Icons.local_offer_outlined,
                  color: AppColors.income,
                  selected: true,
                ),
              ],
            ],
          ),
          if (otherParty.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark2
                    : AppColors.surfaceVariantLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_circle_outlined,
                    size: 20,
                    color: secondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isIncome ? "De" : "Para",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: secondary),
                        ),
                        Text(
                          otherParty,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (isRegistered)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: isDark ? 0.16 : 0.10),
                borderRadius: AppRadius.radiusLg,
                border: Border.all(
                  color: AppColors.income.withValues(
                    alpha: isDark ? 0.35 : 0.22,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppColors.income, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      "Transacción Registrada",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.income,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            CashButton(
              label: isIncome ? "Registrar Ingreso" : "Registrar Gasto",
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => _showAddDialog(context, amount, date, isIncome),
            ),
        ],
      ),
    );
  }

  void _showAddDialog(
    BuildContext context,
    double amount,
    DateTime date,
    bool isIncome,
  ) {
    final provider = Provider.of<AppProvider>(context, listen: false);

    String? selectedCardId;
    if (provider.cards.isNotEmpty) {
      selectedCardId = provider.cards.first.id;
    }

    CashBottomSheet.show<void>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return CashBottomSheet(
            title: isIncome ? "Añadir Ingreso" : "Añadir Gasto",
            subtitle: "Confirma los detalles de la transacción",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: (isIncome ? AppColors.income : AppColors.expense)
                        .withValues(alpha: 0.10),
                    borderRadius: AppRadius.radiusLg,
                    border: Border.all(
                      color: (isIncome ? AppColors.income : AppColors.expense)
                          .withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Monto Total",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(sheetContext).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '\$${amount.toFormattedString(2)}',
                            maxLines: 1,
                            style: Theme.of(sheetContext)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: isIncome
                                      ? AppColors.income
                                      : AppColors.expense,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (provider.cards.isEmpty)
                  Text(
                    context.t('form_no_accounts'),
                    style: Theme.of(
                      sheetContext,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                  )
                else
                  CashSelectorField(
                    label: context.t('form_account'),
                    value: _cardLabel(selectedCardId),
                    placeholder: context.t('form_select_account'),
                    icon: Icons.credit_card_rounded,
                    trailing: _cardCurrency(selectedCardId),
                    onTap: () => _pickCard(
                      sheetContext,
                      provider,
                      (value) => setSheetState(() => selectedCardId = value),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                CashButton(
                  label: "Confirmar y Registrar",
                  icon: const Icon(Icons.check, size: 20),
                  loading: _isRegistering,
                  onPressed: _isRegistering || selectedCardId == null
                      ? null
                      : () => _register(
                          sheetContext,
                          selectedCardId,
                          amount,
                          date,
                          isIncome,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickCard(
    BuildContext context,
    AppProvider provider,
    void Function(String) onSelected,
  ) async {
    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('form_select_account'),
        subtitle: sheetContext.t('form_select_account_hint'),
        child: Column(
          children: [
            for (final card in provider.cards) ...[
              CashCard(
                onTap: () => Navigator.pop(sheetContext, card.id),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      card.isCash
                          ? Icons.payments_outlined
                          : Icons.credit_card_rounded,
                      size: 20,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        card.isCash ? card.name : (card.bankName ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(sheetContext).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      card.currency,
                      style: Theme.of(sheetContext).textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );

    if (selected == null) return;
    onSelected(selected);
  }

  String _cardLabel(String? id) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    for (final card in provider.cards) {
      if (card.id == id) {
        final last4 = card.cardNumber.isNotEmpty && card.cardNumber.length >= 4
            ? card.cardNumber.substring(card.cardNumber.length - 4)
            : '****';
        return card.isCash
            ? '${context.t('card_cash')} · ${card.name}'
            : '${card.bankName ?? 'Tarjeta'} •••• $last4';
      }
    }
    return '';
  }

  String _cardCurrency(String? id) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    for (final card in provider.cards) {
      if (card.id == id) return card.currency;
    }
    return '';
  }

  Future<void> _register(
    BuildContext sheetContext,
    String? selectedCardId,
    double amount,
    DateTime date,
    bool isIncome,
  ) async {
    if (_isRegistering || selectedCardId == null) return;
    setState(() => _isRegistering = true);

    final provider = Provider.of<AppProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final card = provider.cards.firstWhere(
      (c) => c.id == selectedCardId,
      orElse: () => provider.cards.first,
    );
    Navigator.pop(sheetContext);

    final error = await provider.addTransaction(
      amount: isIncome ? amount : -amount,
      title: "Transfermóvil",
      categoryId: "cat_transfermovil",
      currency: card.currency,
      cardId: selectedCardId,
      date: date,
    );

    if (!mounted) return;
    setState(() => _isRegistering = false);

    if (error != null) {
      // Show error SnackBar
      messenger.showSnackBar(
        SnackBar(
          content: Text("Saldo insuficiente en la tarjeta"),
          backgroundColor: AppColors.error,
        ),
      );
    } else {
      // Success
      _scanSMS(); // Refresh list to show 'Registered'
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isIncome
                ? "Ingreso registrado correctamente"
                : "Gasto registrado correctamente",
          ),
          backgroundColor: isIncome ? AppColors.income : AppColors.primaryDark,
        ),
      );
    }
  }
}
