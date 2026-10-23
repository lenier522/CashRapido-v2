import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/ai_service.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Permite subrayar texto con `<u>texto</u>` o `++texto++`, formato que el
/// asistente utiliza para resaltar puntos importantes.
class UnderlineSyntax extends md.InlineSyntax {
  UnderlineSyntax() : super(r'<u>(.*?)</u>|\+\+(.*?)\+\+');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = match[1] ?? match[2] ?? '';
    parser.addNode(md.Element.text('u', text));
    return true;
  }
}

class UnderlineBuilder extends MarkdownElementBuilder {
  final Color color;
  UnderlineBuilder(this.color);

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return Text(
      element.textContent,
      style: (preferredStyle ?? parentStyle ?? const TextStyle()).copyWith(
        decoration: TextDecoration.underline,
        decorationColor: color,
        color: color,
      ),
    );
  }
}

/// Sintaxis Markdown usada por todos los mensajes. Se construye una sola vez
/// para no reasignar la lista de extensiones en cada reconstrucción.
final md.ExtensionSet _chatMarkdownExtensions = md.ExtensionSet(
  md.ExtensionSet.gitHubFlavored.blockSyntaxes,
  [UnderlineSyntax(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
);

enum _ChatRole { user, assistant }

/// Representación inmutable de un mensaje dentro de la conversación visible.
/// No sustituye a [ChatMessage] (que es lo que se persiste): sólo describe lo
/// que la pantalla dibuja, incluyendo errores transitorios que no se guardan.
@immutable
class _ChatMessageView {
  const _ChatMessageView({
    required this.role,
    required this.text,
    this.isError = false,
  });

  final _ChatRole role;
  final String text;
  final bool isError;

  _ChatMessageView withText(String value) =>
      _ChatMessageView(role: role, text: value, isError: isError);
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  /// Sugerencias rápidas mostradas al iniciar una conversación nueva.
  static const List<String> _suggestions = [
    '📊 ¿Cómo van mis finanzas este mes?',
    '💰 ¿Cuál es mi saldo total?',
    '🔍 ¿En qué he gastado más?',
    '💡 Dame un consejo de ahorro',
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AIService _aiService;
  final List<_ChatMessageView> _messages = [];

  /// Indicador visual "escribiendo": activo sólo hasta el primer fragmento.
  bool _isTyping = false;

  /// Cerrojo real de envío. Permanece activo durante TODA la respuesta para
  /// impedir que se abran dos peticiones simultáneas al modelo (antes se
  /// liberaba con el primer fragmento).
  bool _isSending = false;

  /// Identificador de la petición en curso. Si cambia (el usuario abre otra
  /// conversación, empieza una nueva o cierra la pantalla), los fragmentos que
  /// lleguen tarde se descartan en lugar de mezclarse con la conversación
  /// actual.
  int _requestId = 0;

  bool _contextInitialized = false;

  ChatConversation? _currentConversation;
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    // Inicializa el contexto cuando el layout ya es válido.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeChat() {
    // Puede invocarse desde un post-frame callback: si la pantalla ya se cerró
    // no se debe tocar el `context` ni el estado.
    if (!mounted) return;
    if (_contextInitialized) return;

    final provider = Provider.of<AppProvider>(context, listen: false);

    // Ajustes de la app enviados como contexto al modelo.
    final appSettings = {
      'biometrics': provider.biometricsEnabled,
      'theme': provider.themeMode.toString(),
      'mainCurrency': provider.mainCurrency,
      'notifications': provider.notificationsEnabled,
      'chartType': provider.chartType,
    };

    final currency = provider.mainCurrency;
    final categories = provider.categories;

    _aiService = AIService();

    final systemPrompt = _aiService.buildSystemPrompt(
      cards: provider.cards,
      currency: currency,
      allTransactions: provider.transactions,
      categories: categories,
      appSettings: appSettings,
    );

    Iterable<Content>? pastHistory;
    if (_currentConversation != null &&
        _currentConversation!.messages.isNotEmpty) {
      pastHistory = _currentConversation!.messages.map((m) {
        return m.role == 'user'
            ? Content.text(m.text)
            : Content.model([TextPart(m.text)]);
      }).toList();
    }

    _aiService.startChat(systemPrompt, pastHistory: pastHistory);
    _contextInitialized = true;

    // Mensaje de bienvenida sólo al iniciar un chat nuevo.
    if (_currentConversation == null || _currentConversation!.messages.isEmpty) {
      setState(() {
        _messages.add(
          _ChatMessageView(
            role: _ChatRole.assistant,
            text: context.t('ai_welcome_message'),
          ),
        );
      });
    }
  }

  void _loadConversation(ChatConversation? conversation) {
    // Abandona cualquier respuesta en vuelo: al cambiar el identificador, los
    // fragmentos pendientes se descartan en vez de anexarse a esta
    // conversación.
    _requestId++;
    setState(() {
      _currentConversation = conversation;
      _messages.clear();
      _contextInitialized = false;
      _isTyping = false;
      _isSending = false;

      if (conversation != null) {
        for (final msg in conversation.messages) {
          _messages.add(
            _ChatMessageView(
              role: msg.role == 'user' ? _ChatRole.user : _ChatRole.assistant,
              text: msg.text,
            ),
          );
        }
      }
    });
    _initializeChat();
    _scheduleScrollToBottom(force: true);
  }

  Future<void> _saveMessage(String text, String role) async {
    final box = Hive.box<ChatConversation>('ai_chats');
    if (_currentConversation == null) {
      _currentConversation = ChatConversation(
        id: _uuid.v4(),
        title: text.length > 30 ? '${text.substring(0, 30)}...' : text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages: [],
      );
      await box.put(_currentConversation!.id, _currentConversation!);
    }

    _currentConversation!.messages.add(
      ChatMessage(role: role, text: text, timestamp: DateTime.now()),
    );
    _currentConversation!.updatedAt = DateTime.now();
    await _currentConversation!.save();
  }

  Future<void> _sendMessage() async {
    if (_isSending) return; // Evita solicitudes simultáneas.
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final int requestId = ++_requestId;
    _controller.clear();
    setState(() {
      _messages.add(_ChatMessageView(role: _ChatRole.user, text: text));
      _isTyping = true;
      _isSending = true;
    });
    _scheduleScrollToBottom(force: true);

    try {
      // Guardar el mensaje del usuario también dentro del `try`: si falla la
      // persistencia, el aviso de error se muestra y el estado de envío se
      // libera en el `finally` (antes quedaba bloqueado).
      await _saveMessage(text, 'user');

      final stream = _aiService.sendMessageStream(text);
      final buffer = StringBuffer();

      // Refresca la burbuja del asistente con el texto acumulado hasta el
      // momento, limitando la frecuencia de repintado. Sin este control cada
      // fragmento recompone el mensaje completo (copias de la cadena entera)
      // y obliga a flutter_markdown a reparsar toda la respuesta, con un coste
      // cuadrático en la longitud de la respuesta y saltos visibles de layout.
      DateTime lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
      const Duration throttle = Duration(milliseconds: 60);

      void flush({bool force = false}) {
        if (!mounted || buffer.isEmpty) return;
        final DateTime now = DateTime.now();
        if (!force && now.difference(lastUpdate) < throttle) return;
        lastUpdate = now;

        final String fullText = buffer.toString();
        setState(() {
          if (_isTyping) {
            // Primer refresco: se crea el mensaje del asistente.
            _isTyping = false;
            _messages.add(
              _ChatMessageView(role: _ChatRole.assistant, text: fullText),
            );
          } else if (_messages.isNotEmpty) {
            final last = _messages.length - 1;
            _messages[last] = _messages[last].withText(fullText);
          }
        });
        _scheduleScrollToBottom();
      }

      await for (final chunk in stream) {
        // La conversación cambió o la pantalla se cerró: se detiene el consumo
        // del stream para no contaminar otra conversación.
        if (requestId != _requestId || !mounted) break;
        buffer.write(chunk);
        flush();
      }

      // Respuesta abandonada (otra conversación/pantalla cerrada): no se
      // persiste un texto incompleto.
      if (requestId != _requestId || !mounted) return;

      // Muestra el texto íntegro, aunque el último fragmento haya quedado
      // fuera del intervalo de refresco suprimido.
      flush(force: true);

      final response = buffer.toString();
      if (response.trim().isEmpty) {
        // El servicio no devolvió contenido válido: no se guarda ni se presenta
        // como una respuesta definitiva.
        _appendErrorIfMounted();
      } else {
        await _saveMessage(response, 'model');
      }
    } catch (_) {
      // El error nunca se guarda como mensaje del asistente: se muestra como un
      // aviso transitorio y se conserva el mensaje original del usuario.
      if (requestId == _requestId) {
        _appendErrorIfMounted();
      }
    } finally {
      if (requestId == _requestId && mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _appendErrorIfMounted() {
    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add(
        _ChatMessageView(
          role: _ChatRole.assistant,
          text: context.t('ai_error_message'),
          isError: true,
        ),
      );
    });
    _scheduleScrollToBottom(force: true);
  }

  /// Desplaza la conversación sin arrebatar el control al usuario: sólo se
  /// mueve automáticamente si ya estaba cerca del final.
  void _scheduleScrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final isNearBottom = position.maxScrollExtent - position.pixels <= 120;
      if (!force && !isNearBottom) return;

      if (force) {
        _scrollController.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showSuggestions = _messages.length <= 1;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          if (showSuggestions) _buildSuggestions(context),
          Expanded(child: _buildConversation(context)),
          _buildComposer(context),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              context.t('ai_chat_title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: theme.dividerColor),
      ),
    );
  }

  Widget _buildConversation(BuildContext context) {
    final count = _messages.length + (_isTyping ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        if (_isTyping && index == _messages.length) {
          return const _TypingBubble();
        }
        final message = _messages[index];
        if (message.isError) {
          return _ErrorBubble(text: message.text);
        }
        return _MessageBubble(message: message);
      },
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          for (int i = 0; i < _suggestions.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            _SuggestionChip(
              label: _suggestions[i],
              onTap: () => _sendSuggestion(_suggestions[i]),
            ),
          ],
        ],
      ),
    );
  }

  void _sendSuggestion(String prompt) {
    if (_isSending) return;
    // Conserva el comportamiento original: rellena el campo y envía.
    _controller.text = prompt;
    _sendMessage();
  }

  Widget _buildComposer(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark2 : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 1,
                  maxLines: 5,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: context.t('ask_ai_hint'),
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  final hasText = value.text.trim().isNotEmpty;
                  return _SendButton(
                    enabled: hasText && !_isSending,
                    isTyping: _isTyping,
                    onPressed: _sendMessage,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final box = Hive.box<ChatConversation>('ai_chats');

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      context.t('ai_history_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.add_comment_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                context.t('ai_new_chat'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.radiusMd,
              ),
              onTap: () {
                Navigator.pop(context);
                _loadConversation(null);
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ValueListenableBuilder<Box<ChatConversation>>(
                valueListenable: box.listenable(),
                builder: (context, chatsBox, _) {
                  final chats = chatsBox.values.toList()
                    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                  if (chats.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          context.t('ai_no_conversations'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      final selected = _currentConversation?.id == chat.id;
                      return ListTile(
                        title: Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _formatChatDate(chat.updatedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiary,
                          ),
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusMd,
                        ),
                        selected: selected,
                        selectedTileColor: theme.colorScheme.primary.withValues(
                          alpha: 0.10,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _loadConversation(chat);
                        },
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiary,
                          ),
                          tooltip: context.t('delete'),
                          onPressed: () => chat.delete(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatChatDate(DateTime date) {
    final localizations = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final chatDay = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(chatDay).inDays;

    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
      alwaysUse24HourFormat: false,
    );

    if (diffDays == 0) {
      return '${context.t('today')}, $time';
    } else if (diffDays == 1) {
      return '${context.t('yesterday')}, $time';
    } else if (diffDays < 7) {
      return '${localizations.formatMediumDate(date)}, $time';
    } else {
      return '${localizations.formatShortDate(date)}, $time';
    }
  }
}

// ---------------------------------------------------------------------------
// COMPONENTES PRIVADOS DEL CHAT
// ---------------------------------------------------------------------------

/// Globito de un mensaje (usuario o asistente).
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessageView message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUser = message.role == _ChatRole.user;

    final textColor = isUser
        ? theme.colorScheme.onPrimary
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);

    final bubbleColor = isUser
        ? theme.colorScheme.primary
        : (isDark ? AppColors.surfaceDark2 : AppColors.surfaceLight);

    final maxBubbleWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.85,
      680.0,
    );

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.lg),
            topRight: const Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(isUser ? AppRadius.lg : AppRadius.xs),
            bottomRight: Radius.circular(isUser ? AppRadius.xs : AppRadius.lg),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
        ),
        child: MarkdownBody(
          data: message.text,
          selectable: true,
          extensionSet: _chatMarkdownExtensions,
          builders: {'u': UnderlineBuilder(textColor)},
          styleSheet: _chatMarkdownStyleSheet(
            context,
            textColor: textColor,
            isUser: isUser,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const _AssistantAvatar(),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

/// Aviso de error transitorio. No se persiste y nunca se muestra como una
/// respuesta válida del asistente.
class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground = isDark ? AppColors.errorLight : AppColors.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.error.withValues(alpha: 0.12)
                    : AppColors.errorLight,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.xs),
                  bottomRight: Radius.circular(AppRadius.lg),
                ),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.smart_toy_rounded, size: 18, color: primary),
    );
  }
}

/// Indicador de que la solicitud está en curso. Se muestra sólo mientras
/// `_isTyping` es verdadero.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AssistantAvatar(),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark2 : AppColors.surfaceLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(AppRadius.xs),
                bottomRight: Radius.circular(AppRadius.lg),
              ),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dot(primary, 0),
                    const SizedBox(width: 5),
                    _dot(primary, 1),
                    const SizedBox(width: 5),
                    _dot(primary, 2),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color, int index) {
    final phase = (_controller.value - index * 0.15) % 1.0;
    final opacity = 0.35 + 0.65 * (1 - (phase * 2 - 1).abs()).clamp(0.0, 1.0);
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark2
                : primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: isDark
                  ? AppColors.borderDark
                  : primary.withValues(alpha: 0.22),
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.isTyping,
    required this.onPressed,
  });

  final bool enabled;
  final bool isTyping;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final background = enabled
        ? theme.colorScheme.primary
        : (isDark ? AppColors.surfaceDark3 : AppColors.surfaceVariantLight);
    final foreground = enabled
        ? theme.colorScheme.onPrimary
        : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiary);

    return Semantics(
      button: true,
      enabled: enabled,
      label: context.t('send'),
      child: Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  isTyping
                      ? Icons.hourglass_top_rounded
                      : Icons.send_rounded,
                  key: ValueKey<bool>(isTyping),
                  size: 20,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Estilo Markdown adaptado al tema y al tipo de burbuja. Conserva la jerarquía
/// de títulos, listas, tablas y bloques de código, con colores legibles en
/// claro y oscuro.
MarkdownStyleSheet _chatMarkdownStyleSheet(
  BuildContext context, {
  required Color textColor,
  required bool isUser,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final primary = theme.colorScheme.primary;

  final body = (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
    color: textColor,
    fontSize: 15,
    height: 1.45,
  );

  final secondaryText = isUser
      ? textColor.withValues(alpha: 0.8)
      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary);

  final codeBackground = isUser
      ? textColor.withValues(alpha: 0.16)
      : (isDark ? AppColors.surfaceDark3 : AppColors.surfaceVariantLight);
  final codeColor = isUser
      ? textColor
      : (isDark ? AppColors.primary : AppColors.primaryDeep);

  final borderColor = isUser
      ? textColor.withValues(alpha: 0.28)
      : (isDark ? AppColors.borderDark : AppColors.borderLight);

  final linkColor = isUser ? textColor : primary;

  return MarkdownStyleSheet(
    p: body,
    pPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
    strong: body.copyWith(fontWeight: FontWeight.w700),
    em: body.copyWith(fontStyle: FontStyle.italic),
    del: body.copyWith(
      decoration: TextDecoration.lineThrough,
      color: secondaryText,
    ),
    a: body.copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    ),
    h1: body.copyWith(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
    h2: body.copyWith(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3),
    h3: body.copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3),
    h4: body.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
    h5: body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    h6: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    h1Padding: const EdgeInsets.only(
      top: AppSpacing.sm,
      bottom: AppSpacing.xs,
    ),
    h2Padding: const EdgeInsets.only(
      top: AppSpacing.sm,
      bottom: AppSpacing.xs,
    ),
    h3Padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xxs),
    code: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      fontFamily: 'monospace',
      fontSize: 13,
      color: codeColor,
      backgroundColor: codeBackground,
    ),
    codeblockPadding: const EdgeInsets.all(AppSpacing.md),
    codeblockDecoration: BoxDecoration(
      color: codeBackground,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: borderColor),
    ),
    blockquote: body.copyWith(
      color: secondaryText,
      fontStyle: FontStyle.italic,
    ),
    blockquotePadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    blockquoteDecoration: BoxDecoration(
      color: isUser
          ? textColor.withValues(alpha: 0.08)
          : (isDark ? AppColors.surfaceDark3 : AppColors.surfaceVariantLight),
      borderRadius: BorderRadius.circular(AppRadius.xs),
      border: Border(left: BorderSide(color: linkColor, width: 3)),
    ),
    listBullet: body.copyWith(fontWeight: FontWeight.w700, color: linkColor),
    listIndent: AppSpacing.lg,
    listBulletPadding: const EdgeInsets.only(right: 6),
    tableHead: body.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
    tableBody: body.copyWith(fontSize: 13),
    tableBorder: TableBorder.all(color: borderColor, width: 1),
    tableCellsPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: 6,
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: borderColor)),
    ),
    blockSpacing: AppSpacing.sm,
  );
}
