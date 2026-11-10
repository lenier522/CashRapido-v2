import 'dart:async';

import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../licences/art_pay.dart';
import '../licences/license_type.dart';
import '../providers/app_provider.dart';
import '../services/localization_service.dart';
import '../services/qvapay_service.dart';
import '../theme/app_colors.dart';

/// Fases del checkout para decidir qué mostrar en pantalla.
enum _QvaPayPhase { creating, waiting, success, error }

/// Pantalla de pago con QvaPay.
///
/// Crea la factura, abre el pago en el navegador y consulta el estado hasta
/// que el webhook firmado confirma el pago. Solo entonces activa la licencia
/// en [AppProvider]. Funciona tanto en Cuba como en el resto del mundo.
class QvaPayCheckoutScreen extends StatefulWidget {
  const QvaPayCheckoutScreen({super.key, required this.licenseType});

  final LicenseType licenseType;

  @override
  State<QvaPayCheckoutScreen> createState() => _QvaPayCheckoutScreenState();
}

class _QvaPayCheckoutScreenState extends State<QvaPayCheckoutScreen>
    with WidgetsBindingObserver {
  /// Cada 3 s se pregunta al servidor si el webhook ya marcó el pedido.
  static const Duration _pollInterval = Duration(seconds: 3);

  /// Unos 5 minutos de espera automática; después queda la comprobación manual.
  static const int _maxAttempts = 100;

  _QvaPayPhase _phase = _QvaPayPhase.creating;
  QvaPayInvoice? _invoice;
  Timer? _pollTimer;
  int _attempts = 0;
  bool _checking = false;
  String? _message;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createInvoice();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver del navegador conviene comprobar de inmediato, sin esperar
    // a que el temporizador vuelva a dispararse.
    if (state == AppLifecycleState.resumed) {
      _checkOrder(silent: true);
    }
  }

  Future<void> _createInvoice() async {
    _stopPolling();
    setState(() {
      _phase = _QvaPayPhase.creating;
      _invoice = null;
      _attempts = 0;
      _message = null;
      _lastError = null;
    });

    try {
      final QvaPayInvoice invoice = await QvaPayService.createInvoice(
        widget.licenseType,
      );
      if (!mounted) return;

      setState(() {
        _invoice = invoice;
        _phase = _QvaPayPhase.waiting;
        _message = invoice.status == 'paid'
            ? context.t('qvapay_paid_waiting_license')
            : context.t('qvapay_waiting');
      });

      if (invoice.status == 'paid') {
        await _checkOrder(silent: true);
        if (mounted && _phase != _QvaPayPhase.success) {
          _startPolling();
        }
        return;
      }

      final String? url = invoice.paymentUrl;
      if (url != null) {
        await _openPayment(url);
      }
      _startPolling();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _QvaPayPhase.error;
        _lastError = error is QvaPayException
            ? error.message
            : context.t('qvapay_error');
      });
    }
  }

  Future<void> _openPayment(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) {
        setState(() => _lastError = context.t('qvapay_error'));
      }
      return;
    }

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        setState(() => _lastError = context.t('qvapay_open_error'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _lastError = context.t('qvapay_open_error'));
      }
    }
  }

  void _startPolling() {
    _stopPolling();
    _attempts = 0;
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted || _phase == _QvaPayPhase.success) {
        _stopPolling();
        return;
      }
      if (_attempts >= _maxAttempts) {
        _stopPolling();
        setState(() {
          _phase = _QvaPayPhase.waiting;
          _message = context.t('qvapay_polling_timeout');
        });
        return;
      }
      _attempts++;
      _checkOrder(silent: true);
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _checkOrder({required bool silent}) async {
    final QvaPayInvoice? invoice = _invoice;
    if (invoice == null || _checking || _phase == _QvaPayPhase.success) return;

    _checking = true;
    if (!silent && mounted) {
      setState(() {
        _message = context.t('qvapay_checking');
        _lastError = null;
      });
    }

    try {
      final QvaPayOrderStatus order = await QvaPayService.checkOrder(
        orderId: invoice.orderId,
        accessToken: invoice.accessToken,
      );
      if (!mounted) return;

      if (order.isPaid) {
        await _activateLicense(order);
        return;
      }

      if (order.isPending) {
        setState(() {
          _phase = _QvaPayPhase.waiting;
          _lastError = null;
          _message = context.t('qvapay_waiting');
        });
        return;
      }

      _stopPolling();
      setState(() {
        _phase = _QvaPayPhase.error;
        _lastError = switch (order.status) {
          'cancelled' => context.t('qvapay_cancelled'),
          'failed' => context.t('qvapay_failed'),
          _ => context.t('qvapay_failed'),
        };
      });
    } catch (error) {
      if (!mounted) return;
      final String message = error is QvaPayException
          ? error.message
          : context.t('qvapay_error');
      if (!silent) {
        setState(() => _lastError = message);
      } else {
        // Un fallo puntual de red no debe romper la espera automática.
        _lastError = message;
        if (_message == null) {
          setState(() => _message = context.t('qvapay_waiting'));
        }
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _activateLicense(QvaPayOrderStatus order) async {
    final String? licenseCode = order.licenseCode;
    if (!order.licenseReady || licenseCode == null || licenseCode.isEmpty) {
      setState(() {
        _phase = _QvaPayPhase.waiting;
        _lastError = null;
        _message = context.t('qvapay_paid_waiting_license');
      });
      return;
    }

    final LicenseType? paidType = QvaPayService.licenseTypeForPlanId(
      order.planId ?? '',
    );
    if (paidType != widget.licenseType) {
      _stopPolling();
      setState(() {
        _phase = _QvaPayPhase.error;
        _lastError = context.t('qvapay_plan_mismatch');
      });
      return;
    }

    final DateTime expiresAt =
        QvaPayService.parseExpiresAt(order.expiresAt) ??
        DateTime.now().add(Duration(days: widget.licenseType.durationDays));

    context.read<AppProvider>().setLicenseType(
      widget.licenseType,
      expirationDate: expiresAt,
    );

    _stopPolling();
    setState(() {
      _phase = _QvaPayPhase.success;
      _lastError = null;
      _message = context.t('qvapay_paid');
    });
  }

  @override
  Widget build(BuildContext context) {
    final LicenseType licenseType = widget.licenseType;
    final Color accent = ArtPayService.getLicenseColor(licenseType);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A14),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.t('qvapay_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PlanSummary(licenseType: licenseType, accent: accent),
          const SizedBox(height: 20),
          _StatusCard(
            phase: _phase,
            message: _message,
            error: _lastError,
            accent: accent,
            attempts: _attempts,
            maxAttempts: _maxAttempts,
          ),
          const SizedBox(height: 24),
          if (_phase == _QvaPayPhase.success)
            _buildSuccessButton()
          else ...[
            if (_invoice?.paymentUrl != null) ...[
              _buildActionButton(
                label: context.t('qvapay_open'),
                icon: Icons.open_in_new_rounded,
                color: accent,
                onPressed: () => _openPayment(_invoice!.paymentUrl!),
              ),
              const SizedBox(height: 12),
            ],
            if (_invoice != null && _phase != _QvaPayPhase.creating)
              _buildActionButton(
                label: context.t('qvapay_check'),
                icon: Icons.refresh_rounded,
                color: AppColors.primary,
                loading: _checking,
                onPressed: _checking ? null : () => _checkOrder(silent: false),
              ),
            if (_phase == _QvaPayPhase.error) ...[
              const SizedBox(height: 12),
              _buildActionButton(
                label: context.t('qvapay_new_order'),
                icon: Icons.receipt_long_outlined,
                color: Colors.white24,
                onPressed: _createInvoice,
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                context.t('cancel'),
                style: GoogleFonts.outfit(color: Colors.white54),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 18,
                color: Colors.white38,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t('qvapay_secure'),
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessButton() {
    return _buildActionButton(
      label: context.t('qvapay_done'),
      icon: Icons.check_circle_rounded,
      color: AppColors.primary,
      onPressed: () => Navigator.pop(context, true),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Resumen del plan que se está pagando.
class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.licenseType, required this.accent});

  final LicenseType licenseType;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141428),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              ArtPayService.getLicenseIcon(licenseType),
              color: accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ArtPayService.getLicenseName(licenseType),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${licenseType.durationDays} ${context.t('days')}',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${ArtPayService.getPriceUSD(licenseType)}',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              Text(
                'USD',
                style: GoogleFonts.outfit(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de estado del pago.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.phase,
    required this.accent,
    required this.attempts,
    required this.maxAttempts,
    this.message,
    this.error,
  });

  final _QvaPayPhase phase;
  final Color accent;
  final int attempts;
  final int maxAttempts;
  final String? message;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final bool isError = phase == _QvaPayPhase.error;
    final bool isSuccess = phase == _QvaPayPhase.success;
    final Color color = isError
        ? AppColors.error
        : isSuccess
        ? AppColors.income
        : accent;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          if (phase == _QvaPayPhase.creating)
            CircularProgressIndicator(color: color)
          else
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : isSuccess
                  ? Icons.check_circle_outline_rounded
                  : Icons.hourglass_top_rounded,
              color: color,
              size: 40,
            ),
          const SizedBox(height: 14),
          Text(
            _title(context),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ] else if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          if (phase == _QvaPayPhase.waiting && attempts > 0) ...[
            const SizedBox(height: 12),
            Text(
              context
                  .t('qvapay_polling')
                  .replaceAll('{n}', attempts.toString())
                  .replaceAll('{max}', maxAttempts.toString()),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  String _title(BuildContext context) {
    return switch (phase) {
      _QvaPayPhase.creating => context.t('qvapay_creating'),
      _QvaPayPhase.waiting => context.t('qvapay_pending_title'),
      _QvaPayPhase.success => context.t('qvapay_success_title'),
      _QvaPayPhase.error => context.t('qvapay_error_title'),
    };
  }
}
