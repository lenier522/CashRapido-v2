import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';

class TransferMovilScreen extends StatefulWidget {
  const TransferMovilScreen({super.key});

  @override
  State<TransferMovilScreen> createState() => _TransferMovilScreenState();
}

class _TransferMovilScreenState extends State<TransferMovilScreen> {
  final SmsQuery _query = SmsQuery();
  bool _isLoading = false;
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
      builder: (context) => AlertDialog(
        title: Text(
          "Permiso necesario",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Para leer las confirmaciones de pago, necesitamos acceso a tus SMS. Por favor habilita el permiso en la configuración.",
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancelar",
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(
              "Abrir Configuración",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
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
      setState(() {
        _permissionStatus = status;
      });
      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          _showPermissionDialog();
        } else {
          final newStatus = await Permission.sms.request();
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
            body.contains("Pago completado");
      }).toList();

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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Transfermóvil",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 22,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sms_failed_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  "Permiso Requerido",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "No podemos leer tus mensajes para importar transacciones sin tu permiso.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    if (_permissionStatus!.isPermanentlyDenied) {
                      openAppSettings();
                    } else {
                      _checkPermissionAndScan();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    "Conceder Permiso",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Transfermóvil",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold, // Bold title
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: _isLoading ? null : _checkPermissionAndScan,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : _messages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.smartphone_outlined, // Changed icon
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "No se encontraron transferencias",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tus pagos de Transfermóvil aparecerán aquí",
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.builder(
              // Changed to builder
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final sms = _messages[index];
                return Padding(
                  // Add padding for spacing
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildMessageCard(context, sms),
                );
              },
            ),
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

    double amount = 0.0;
    String otherParty = "";

    if (isIncome) {
      final match = RegExp(r"de\s*([\d\.]+)\s*CUP").firstMatch(body);
      amount = double.tryParse(match?.group(1) ?? "0") ?? 0.0;
      final accMatch = RegExp(r"cuenta\s*(\d+)").firstMatch(body);
      if (accMatch != null) {
        otherParty =
            "Cuenta ...${accMatch.group(1)?.substring(accMatch.group(1)!.length - 4)}";
      }
    } else if (isPayment) {
      // Logic for "Pago completado"
      // Priority: "Importe pagado", if not found, fallback to "Importe"
      final paidMatch = RegExp(
        r"Importe pagado:\s*([\d\.]+)\s*CUP",
      ).firstMatch(body);
      if (paidMatch != null) {
        amount = double.tryParse(paidMatch.group(1) ?? "0") ?? 0.0;
      } else {
        final match = RegExp(r"Importe:\s*([\d\.]+)\s*CUP").firstMatch(body);
        amount = double.tryParse(match?.group(1) ?? "0") ?? 0.0;
      }

      final entityMatch = RegExp(r"Entidad:\s*(.+)").firstMatch(body);
      if (entityMatch != null) {
        otherParty = "A: ${entityMatch.group(1)?.trim()}";
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
      if (t.amount.toStringAsFixed(2) != targetAmount.toStringAsFixed(2)) {
        return false;
      }
      return t.date.difference(date).inSeconds.abs() < 60;
    });

    final cardColor = isIncome
        ? Colors.green.shade400
        : Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [cardColor.withOpacity(0.15), cardColor.withOpacity(0.05)]
              : [cardColor.withOpacity(0.08), cardColor.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cardColor.withOpacity(isDark ? 0.3 : 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(isDark ? 0.15 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cardColor.withOpacity(isDark ? 0.25 : 0.15),
                    cardColor.withOpacity(isDark ? 0.15 : 0.08),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? cardColor.withOpacity(0.3)
                          : Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isIncome ? Icons.south_west : Icons.north_east,
                      color: cardColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIncome
                              ? "Transferencia Recibida"
                              : "Transferencia Enviada",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${date.day}/${date.month}/${date.year} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isRegistered)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(isDark ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(isDark ? 0.4 : 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Colors.green.shade300,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Registrado",
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade300,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Body content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount Display - Large and prominent
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Monto",
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(2)}",
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: cardColor,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            "CUP",
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.grey[500]
                                  : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Other party info if available
                  if (otherParty.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_circle_outlined,
                            size: 18,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isIncome ? "De" : "Para",
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                otherParty,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: isRegistered
                        ? Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.green.withOpacity(0.15)
                                  : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.green.withOpacity(
                                  isDark ? 0.3 : 0.2,
                                ),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade300,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Transacción Registrada",
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () =>
                                _showAddDialog(context, amount, date, isIncome),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cardColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: cardColor.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_circle_outline, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  isIncome
                                      ? "Registrar Ingreso"
                                      : "Registrar Gasto",
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isIncome
        ? Colors.green.shade400
        : Theme.of(context).colorScheme.primary;

    String? selectedCardId;
    if (provider.cards.isNotEmpty) {
      selectedCardId = provider.cards.first.id;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 24,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[600] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isIncome ? "Añadir Ingreso" : "Añadir Gasto",
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Confirma los detalles de la transacción",
                  style: GoogleFonts.outfit(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // Amount Display
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cardColor.withOpacity(isDark ? 0.3 : 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Monto Total",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white.withOpacity(0.9)
                              : Colors.black87,
                        ),
                      ),
                      Text(
                        "\$${amount.toStringAsFixed(2)}",
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: cardColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  "Seleccionar Tarjeta",
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedCardId,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      hint: const Text("Selecciona una tarjeta"),
                      items: provider.cards.map((card) {
                        return DropdownMenuItem(
                          value: card.id,
                          child: Row(
                            children: [
                              Icon(
                                Icons.credit_card,
                                size: 20,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "${card.bankName ?? 'Tarjeta'} •••• ${card.cardNumber.isNotEmpty && card.cardNumber.length >= 4 ? card.cardNumber.substring(card.cardNumber.length - 4) : '****'}",
                                  style: GoogleFonts.outfit(),
                                ),
                              ),
                              Text(
                                card.currency,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedCardId = val),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isIncome
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (selectedCardId == null) {
                        return;
                      }

                      final card = provider.cards.firstWhere(
                        (c) => c.id == selectedCardId,
                      );
                      Navigator.pop(ctx);

                      final error = await provider.addTransaction(
                        amount: isIncome ? amount : -amount,
                        title: "Transfermóvil",
                        categoryId: "cat_transfermovil",
                        currency: card.currency,
                        cardId: selectedCardId,
                        date: date,
                      );

                      if (error != null) {
                        // Show error SnackBar
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Saldo insuficiente en la tarjeta",
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: Colors.red.shade600,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      } else {
                        // Success
                        _scanSMS(); // Refresh list to show 'Registered'
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isIncome
                                    ? "Ingreso registrado correctamente"
                                    : "Gasto registrado correctamente",
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: cardColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      "Confirmar y Registrar",
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
