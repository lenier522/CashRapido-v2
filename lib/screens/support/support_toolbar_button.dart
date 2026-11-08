import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../services/localization_service.dart';
import '../../services/support_chat_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_icon_button.dart';
import 'support_chat_screen.dart';
import 'support_inbox_screen.dart';

/// Botón de soporte del inicio, con el contador de mensajes sin leer.
///
/// Lo ven todas las cuentas: el cliente abre su chat y el equipo de soporte,
/// la bandeja. La pantalla se decide al tocar y se vuelve a preguntar al
/// servidor, de modo que un cambio de sesión no deje el botón apuntando a la
/// pantalla equivocada (ni muestre el aviso de «solo soporte» a un cliente).
class SupportToolbarButton extends StatefulWidget {
  const SupportToolbarButton({super.key});

  @override
  State<SupportToolbarButton> createState() => _SupportToolbarButtonState();
}

class _SupportToolbarButtonState extends State<SupportToolbarButton> {
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  StreamSubscription<dynamic>? _authSubscription;

  bool _admin = false;
  bool _starting = false;
  bool _signedIn = false;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _signedIn = SupabaseService.isSignedIn;
    if (SupabaseService.isInitialized) {
      _authSubscription = SupabaseService.authStateChanges.listen(
        (_) => _onAuthChanged(),
        onError: (Object error) =>
            debugPrint('Sesión de soporte (tiempo real): $error'),
      );
    }
    _start();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  /// Al entrar o salir de la cuenta se reinicia el contador: el estado de
  /// soporte y los no leídos son de la cuenta que esté conectada ahora.
  void _onAuthChanged() {
    final bool signedIn = SupabaseService.isSignedIn;
    if (signedIn == _signedIn) return;
    _signedIn = signedIn;

    _subscription?.cancel();
    _subscription = null;
    if (!mounted) return;

    setState(() {
      _admin = false;
      _unread = 0;
    });
    if (signedIn) _start();
  }

  Future<void> _start() async {
    if (_starting || _subscription != null || !SupabaseService.isSignedIn) {
      return;
    }
    _starting = true;
    try {
      final bool admin = await SupportChatService.isSupportAdmin();
      if (!mounted) return;
      setState(() => _admin = admin);
      await _load();
      if (!mounted) return;
      _subscription = SupportChatService.watchConversations().listen(
        _apply,
        onError: (Object error) =>
            debugPrint('Contador de soporte (tiempo real): $error'),
      );
    } catch (error) {
      debugPrint('Contador de soporte: $error');
    } finally {
      _starting = false;
    }
  }

  /// Primera carga del contador; el resto llega por el flujo en tiempo real.
  Future<void> _load() async {
    try {
      final List<Map<String, dynamic>> rows =
          await SupportChatService.conversationCounters();
      if (mounted) _apply(rows);
    } catch (error) {
      debugPrint('Contador de soporte: $error');
    }
  }

  void _apply(List<Map<String, dynamic>> rows) {
    final int unread = SupportChatService.unreadFromRows(rows, admin: _admin);
    if (mounted && unread != _unread) setState(() => _unread = unread);
  }

  Future<void> _open() async {
    // Sin sesión se abre el chat, que pide conectar Google. Con sesión se
    // comprueba de nuevo contra el servidor: un cliente nunca debe caer en la
    // bandeja del soporte. Si la comprobación falla, se usa el chat.
    bool admin = false;
    if (SupabaseService.isSignedIn) {
      try {
        admin = await SupportChatService.isSupportAdmin(refresh: true);
      } catch (error) {
        debugPrint('Comprobar cuenta de soporte: $error');
        admin = false;
      }
      if (mounted) setState(() => _admin = admin);
    }
    if (!mounted) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            admin ? const SupportInboxScreen() : const SupportChatScreen(),
      ),
    );
    if (!mounted) return;

    // Al volver del chat la sesión puede haberse conectado allí; en ese caso
    // hay que arrancar el contador. Si ya estaba activo, basta con refrescar.
    if (!SupabaseService.isSignedIn) return;
    if (_subscription == null) {
      await _start();
    } else {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    // El botón lo ven todas las cuentas, con o sin sesión: sin sesión el chat
    // muestra el aviso para conectar Google. El contador solo aplica con
    // sesión, y arranca en cuanto la haya (la sesión puede iniciarse después
    // de montar el inicio).
    if (SupabaseService.isSignedIn && _subscription == null && !_starting) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }

    return CashIconButton(
      icon: Icons.support_agent_rounded,
      size: 44,
      iconSize: 21,
      bordered: true,
      tooltip: context.t('support_title'),
      onPressed: _open,
      badge: SupabaseService.isSignedIn && _unread > 0
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 1,
              ),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: AppRadius.radiusSm,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                ),
              ),
              child: Text(
                _unread > 99 ? '99+' : '$_unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }
}
