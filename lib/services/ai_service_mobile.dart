import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/models.dart';

import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:flutter_gemma/core/message.dart';
import 'package:flutter_gemma/core/chat.dart';
import 'package:flutter_gemma/core/model_response.dart';
import 'package:flutter_gemma/pigeon.g.dart';

class AIService {
  // STRICTLY confidential API Key provided by user for this session.
  // API Keys Rotation List
  static const List<String> _apiKeys = [
    'AIzaSyD13Lswvo0BpvE_T2a9w7OuotB6LufcIVs', // Key 1
    'AIzaSyCDOj7bXUEdmT_C16eZGb6P864pwjM_wHY', // Key 2 (Backup)
    'AIzaSyDLmJ4Nn8okknUh4MOhK7t7pgvxQqIA2k4', // Key 3 (Backup)
    'AIzaSyA1dwjz58otakuHVwq66ySOGBvcbeXaQs4', // Key 4 (Backup)
    'AIzaSyDo44qHm9bDrP15WzKxwxaTe8tU3Yp2C4U', // Key 5 (Backup)
  ];

  // Model Name (User Preference)
  static const String _modelName = 'gemini-2.5-flash-lite';

  late GenerativeModel _model;
  ChatSession? _chatSession;
  int _currentKeyIndex = 0;
  String? _lastSystemPrompt; // To restore session if needed

  final bool useOfflineAI;
  final String? offlineModelPath;
  bool _offlineInitialized = false;
  InferenceChat? _offlineChat;

  AIService({this.useOfflineAI = false, this.offlineModelPath}) {
    _initModel();
  }

  void _initModel() async {
    if (useOfflineAI) {
      if (offlineModelPath != null && offlineModelPath!.isNotEmpty) {
        print("Initializing Offline AI with model path: $offlineModelPath");
      }
      // Note: flutter_gemma requires initialization before usage.
      // We assume it's either initialized globally or here.
      // But for simplicity, we'll initialize it if needed or just use it.
      // The actual instantiation is handled by FlutterGemmaPlugin.instance
    } else {
      print("Initializing Cloud AI with Key index: $_currentKeyIndex");
      _model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKeys[_currentKeyIndex],
      );
    }
  }

  void startChat(String contextPrompt) {
    _lastSystemPrompt = contextPrompt;
    if (!useOfflineAI) {
      _chatSession = _model.startChat(history: [Content.text(contextPrompt)]);
    } else {
      // Async initialization for offline chat is handled when sending messages
      _offlineChat = null;
    }
  }

  Future<void> _ensureOfflineInitialized() async {
    if (!_offlineInitialized &&
        offlineModelPath != null &&
        offlineModelPath!.isNotEmpty) {
      try {
        // According to the modern API, we get an active model instance then create a chat
        final inferenceModel = await FlutterGemma.getActiveModel(
          maxTokens: 4096,
          preferredBackend: PreferredBackend.cpu,
        );
        _offlineChat = await inferenceModel.createChat(
          temperature: 1.0,
          topK: 64,
          topP: 0.95,
        );

        // Add system prompt to the chat history if we have one
        if (_lastSystemPrompt != null) {
          await _offlineChat!.addQueryChunk(
            Message.text(text: "System: $_lastSystemPrompt", isUser: true),
          );
          // Provide a dummy acknowledge
          await _offlineChat!.addQueryChunk(
            Message.text(text: "Understood.", isUser: false),
          );
        }

        print("FlutterGemma Initialized and Chat Created");
        _offlineInitialized = true;
      } catch (e) {
        print("Error initializing FlutterGemma: $e");
      }
    }
  }

  // Support for streaming responses (both Cloud and Offline)
  Stream<String> sendMessageStream(String message) async* {
    if (useOfflineAI) {
      if (offlineModelPath == null || offlineModelPath!.isEmpty) {
        yield "Error: No se ha importado ningún modelo offline. Ve a Configuración para importarlo.";
        return;
      }

      await _ensureOfflineInitialized();

      if (_offlineChat == null) {
        yield "Error: Chat offline no está listo.";
        return;
      }

      await _offlineChat!.addQueryChunk(
        Message.text(text: message, isUser: true),
      );

      try {
        final stream = _offlineChat!.generateChatResponseAsync();

        // Accumulate full response to add to history afterwards
        String fullResponse = "";

        await for (final response in stream) {
          if (response is TextResponse) {
            fullResponse += response.token;
            yield response.token;
          }
        }

        if (fullResponse.isNotEmpty) {
          await _offlineChat!.addQueryChunk(
            Message.text(text: fullResponse, isUser: false),
          );
        }
      } catch (e) {
        yield "Error del modelo offline: $e";
      }
      return;
    }

    // Cloud Stream
    if (_chatSession == null) {
      if (_lastSystemPrompt != null) {
        startChat(_lastSystemPrompt!);
      } else {
        _chatSession = _model.startChat();
      }
    }

    try {
      final stream = _chatSession!.sendMessageStream(Content.text(message));
      await for (final chunk in stream) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      print("Error with Key $_currentKeyIndex: $e");
      yield "Error de conexión: $e";
    }
  }

  Future<String> sendMessage(String message) async {
    return _attemptSendMessage(message, 0);
  }

  Future<String> _attemptSendMessage(String message, int attempt) async {
    if (useOfflineAI) {
      try {
        if (offlineModelPath == null || offlineModelPath!.isEmpty) {
          return "Error: No se ha importado ningún modelo offline. Ve a Configuración para importarlo.";
        }

        await _ensureOfflineInitialized();

        if (_offlineChat == null) {
          return "Error: Chat offline no está listo.";
        }

        await _offlineChat!.addQueryChunk(
          Message.text(text: message, isUser: true),
        );
        final response = await _offlineChat!.generateChatResponse();

        String responseText = "";
        if (response is TextResponse) {
          responseText = response.token;
        }

        if (responseText.isNotEmpty) {
          await _offlineChat!.addQueryChunk(
            Message.text(text: responseText, isUser: false),
          );
          return responseText;
        }

        return "No pude generar una respuesta offline.";
      } catch (e) {
        return "Error del modelo offline: $e";
      }
    }

    // Ensure session exists
    if (_chatSession == null) {
      if (_lastSystemPrompt != null) {
        startChat(_lastSystemPrompt!);
      } else {
        _chatSession = _model.startChat();
      }
    }

    try {
      final response = await _chatSession!.sendMessage(Content.text(message));
      return response.text ?? "Lo siento, no pude generar una respuesta.";
    } catch (e) {
      print("Error with Key $_currentKeyIndex: $e");

      // If we haven't tried all keys yet, rotate and retry
      if (attempt < _apiKeys.length) {
        _rotateKey();

        // Restore Session State
        // We must create a new chat session with the OLD history
        // Note: The failed message is NOT in history yet.
        final oldHistory = _chatSession?.history ?? [];

        // Re-init with new key
        _initModel();

        // Start new session with preserved history
        // Note: If startChat was called with a system prompt in history, it's there.
        _chatSession = _model.startChat(history: oldHistory.toList());

        return _attemptSendMessage(message, attempt + 1);
      }

      return "Error de conexión (Probé todas las llaves): $e";
    }
  }

  void _rotateKey() {
    _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
  }

  String buildSystemPrompt({
    required List<AccountCard> cards,
    required String currency,
    required List<InternalTransaction> allTransactions,
    required List<Category> categories,
    required Map<String, dynamic> appSettings,
  }) {
    // 1. Account Details
    final accountsInfo = cards
        .map(
          (c) =>
              "- ${c.name}: ${c.balance.toStringAsFixed(2)} ${c.currency} (${c.isCash ? 'Efectivo' : c.bankName ?? 'Banco'}) [ID: ${c.id}]",
        )
        .join('\n');
    final totalBalance = cards
        .fold(0.0, (sum, c) => sum + c.balance)
        .toStringAsFixed(2);

    // 2. Category Map (ID -> Name)
    final catMap = {for (var c in categories) c.id: c.name};

    // 3. Transactions Analysis (Top 50)
    final recentTx = allTransactions
        .take(50)
        .map((t) {
          final catName = catMap[t.categoryId] ?? t.categoryId;
          return "- ${t.date.toIso8601String().split('T')[0]}: ${t.title} (${t.amount} ${t.currency}) [$catName]";
        })
        .join('\n');

    // 4. Financial Summary (30 Days)
    final now = DateTime.now();
    final last30Days = allTransactions.where(
      (t) => t.date.isAfter(now.subtract(const Duration(days: 30))),
    );
    double income30 = 0;
    double expense30 = 0;
    for (var t in last30Days) {
      if (t.amount > 0) {
        income30 += t.amount;
      } else {
        expense30 += t.amount.abs();
      }
    }

    // 5. Settings
    final settingsInfo = appSettings.entries
        .map((e) => "- ${e.key}: ${e.value}")
        .join('\n');

    return '''
Actúa como la IA Central ("Cerebro") de la app "CashRapido". Tienes ACCESO TOTAL a los datos del usuario.
Tu misión es ser un asistente financiero OMNISCIENTE y PROACTIVO.

ESTADO DE LA APLICACIÓN:
[Configuración Global]
$settingsInfo

[Cuentas y Balances]
$accountsInfo
Total Global Aproximado: $totalBalance

[Resumen Últimos 30 Días]
Ingresos: ${income30.toStringAsFixed(2)}
Gastos: ${expense30.toStringAsFixed(2)}

[Transacciones Recientes (Últimas 50)]
$recentTx

[Categorías Disponibles]
${categories.map((c) => c.name).join(', ')}

INSTRUCCIONES CLAVE:
1. ERES EXPERTO: Si te preguntan "¿Cómo voy este mes?", usa los datos de "Resumen Últimos 30 Días" y compara.
2. DETALLES: Si te preguntan por una transacción específica, búscala en la lista de recientes.
3. CONSEJOS: Si Gastos > Ingresos, ALERTA al usuario amablemente.
4. CONFIGURACIÓN: Si te preguntan "¿Tengo activada la biometría?", mira [Configuración Global].
5. IDIOMA: Responde en el idioma del usuario.
6. DIRECTO: No saludes dos veces. Ve al dato.

Ejemplo: "Tienes activada la biometría. Este mes has gastado \$${expense30.toStringAsFixed(2)}, principalmente en..."
''';
  }
}
