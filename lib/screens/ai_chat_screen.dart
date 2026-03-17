import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../services/ai_service.dart';
import '../providers/app_provider.dart';
import '../services/localization_service.dart';
import '../models/models.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AIService _aiService;
  final List<Map<String, String>> _messages =
      []; // 'role': 'user' | 'model', 'text': '...'
  bool _isTyping = false;
  bool _contextInitialized = false;
  
  ChatConversation? _currentConversation;
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    // Initialize context prompt after valid layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  void _initializeChat() {
    if (_contextInitialized) return;

    final provider = Provider.of<AppProvider>(context, listen: false);

    // Gather settings
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
    if (_currentConversation != null && _currentConversation!.messages.isNotEmpty) {
      pastHistory = _currentConversation!.messages.map((m) {
        return m.role == 'user' 
            ? Content.text(m.text) 
            : Content.model([TextPart(m.text)]);
      }).toList();
    }

    _aiService.startChat(systemPrompt, pastHistory: pastHistory);
    _contextInitialized = true;

    // Add welcome message only if it's a new chat
    if (_currentConversation == null || _currentConversation!.messages.isEmpty) {
      setState(() {
        _messages.add({'role': 'model', 'text': context.t('ai_welcome_message')});
      });
    }
  }

  void _loadConversation(ChatConversation? conversation) {
    setState(() {
      _currentConversation = conversation;
      _messages.clear();
      _contextInitialized = false;
      
      if (conversation != null) {
        for (var msg in conversation.messages) {
          _messages.add({'role': msg.role, 'text': msg.text});
        }
      }
    });
    _initializeChat();
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
    
    _currentConversation!.messages.add(ChatMessage(
      role: role,
      text: text,
      timestamp: DateTime.now(),
    ));
    _currentConversation!.updatedAt = DateTime.now();
    await _currentConversation!.save();
  }

  Future<void> _sendMessage() async {
    if (_isTyping) return; // Prevent multiple requests at once
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });
    _scrollToBottom();

    _scrollToBottom();
    await _saveMessage(text, 'user');

    try {
      final stream = _aiService.sendMessageStream(text);
      bool firstChunkReceived = false;
      String fullModelResponse = "";

      await for (final chunk in stream) {
        if (mounted) {
          setState(() {
            if (!firstChunkReceived) {
              _isTyping = false;
              _messages.add({'role': 'model', 'text': chunk});
              fullModelResponse = chunk;
              firstChunkReceived = true;
            } else {
              _messages.last['text'] = _messages.last['text']! + chunk;
              fullModelResponse += chunk;
            }
          });
          _scrollToBottom();
        }
      }

      await _saveMessage(fullModelResponse, 'model');

      if (!firstChunkReceived && mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'role': 'model',
            'text': "${context.t('error_connecting')}: $e",
          });
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.smart_toy_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              context.t('ai_chat_title'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      drawer: _buildDrawer(),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _buildTypingIndicator();
                  }
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';
                  return _buildMessageBubble(msg['text']!, isUser);
                },
              ),
            ),
            _buildInputArea(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.1),
              child: Icon(
                Icons.smart_toy_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withBlue(255),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser
                    ? null
                    : (isDark ? const Color(0xFF2A2A3C) : Colors.grey.shade100),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(isUser ? 24 : 8),
                  bottomRight: Radius.circular(isUser ? 8 : 24),
                ),
                boxShadow: [
                  if (isUser)
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  else
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Text(
                text,
                style: GoogleFonts.outfit(
                  color: isUser
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 24), // Balance spacing for avatar
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.1),
            child: Icon(
              Icons.smart_toy_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A3C) : Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final box = Hive.box<ChatConversation>('ai_chats');
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: Center(
              child: Text(
                'Historial de Chats',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_comment_rounded),
            title: Text('Nuevo Chat', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              _loadConversation(null);
            },
          ),
          const Divider(),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box<ChatConversation> chatsBox, _) {
                final chats = chatsBox.values.toList()
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                if (chats.isEmpty) {
                  return const Center(child: Text('No hay conversaciones aún.'));
                }
                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    return ListTile(
                      title: Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 15),
                      ),
                      subtitle: Text(
                        "\${chat.updatedAt.day}/\${chat.updatedAt.month}/\${chat.updatedAt.year}",
                        style: GoogleFonts.outfit(fontSize: 12),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      selected: _currentConversation?.id == chat.id,
                      selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      onTap: () {
                        Navigator.pop(context);
                        _loadConversation(chat);
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
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
    );
  }



  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A3C) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.outfit(fontSize: 15),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: context.t('ask_ai_hint'),
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: Theme.of(context).disabledColor,
                        fontSize: 15,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withBlue(255),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
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
