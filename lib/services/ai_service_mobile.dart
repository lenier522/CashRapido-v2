import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/models.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

class AIService {
  // STRICTLY confidential API Key provided by user for this session.
  // API Keys Rotation List from .env
  static final List<String> _apiKeys = [
    dotenv.get('GEMINI_API_KEY_1', fallback: ''),
    dotenv.get('GEMINI_API_KEY_2', fallback: ''),
    dotenv.get('GEMINI_API_KEY_3', fallback: ''),
    dotenv.get('GEMINI_API_KEY_4', fallback: ''),
    dotenv.get('GEMINI_API_KEY_5', fallback: ''),
  ].where((k) => k.isNotEmpty).toList();

  // Model Name (User Preference)
  static const String _modelName = 'gemini-2.5-flash-lite';

  late GenerativeModel _model;
  ChatSession? _chatSession;
  int _currentKeyIndex = 0;
  String? _lastSystemPrompt; // To restore session if needed

  AIService() {
    _initModel();
  }

  void _initModel() async {
    print("Initializing Cloud AI with Key index: $_currentKeyIndex");
    _model = GenerativeModel(
      model: _modelName,
      apiKey: _apiKeys[_currentKeyIndex],
    );
  }

  void startChat(String contextPrompt, {Iterable<Content>? pastHistory}) {
    _lastSystemPrompt = contextPrompt;
    List<Content> history = [Content.text(contextPrompt)];
    if (pastHistory != null) {
      history.addAll(pastHistory);
    }
    _chatSession = _model.startChat(history: history);
  }

  // Support for streaming responses
  Stream<String> sendMessageStream(String message) async* {
    if (_chatSession == null) {
      if (_lastSystemPrompt != null) {
        startChat(_lastSystemPrompt!);
      } else {
        _chatSession = _model.startChat();
      }
    }

    // Los errores se propagan al consumidor para que la interfaz pueda
    // distinguir un fallo real de una respuesta del modelo (antes se emitían
    // como texto y terminaban guardándose como si fuese una respuesta válida).
    final stream = _chatSession!.sendMessageStream(Content.text(message));
    await for (final chunk in stream) {
      if (chunk.text != null) {
        yield chunk.text!;
      }
    }
  }

  Future<String> sendMessage(String message) async {
    return _attemptSendMessage(message, 0);
  }

  Future<String> _attemptSendMessage(String message, int attempt) async {
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
              "- ${c.name}: ${c.balance.toFormattedString(2)} ${c.currency} (${c.isCash ? 'Efectivo' : c.bankName ?? 'Banco'}) [ID: ${c.id}]",
        )
        .join('\n');
    final totalBalance = cards
        .fold(0.0, (sum, c) => sum + c.balance)
        .toFormattedString(2);

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
Actúa como el Asistente Financiero Inteligente y Personal de la app "CashRapido". Tienes acceso en tiempo real a las finanzas y configuración del usuario.

PERSONALIDAD Y TONO:
- Sé sumamente profesional, intuitivo, amigable, empático y constructivo.
- Exprésate con un lenguaje cálido, motivador y educado (saluda amigablemente si es el inicio de la charla, felicita si el balance es positivo, orienta con tacto si hay gastos elevados).
- Usa emojis financieros y amigables con buen gusto (💰, 📊, 💡, ✨, 🎯, 📈).
- Utiliza SIEMPRE formato Markdown enriquecido para estructurar tus respuestas:
  * Usa **negrita** para destacar cifras de dinero, balances, categorías y nombres importantes.
  * Usa *cursiva* para sugerencias, notas o aclaraciones suaves.
  * Usa <u>subrayado</u> para destacar puntos críticos o acciones prioritarias.
  * Usa viñetas (- o *) y listas numeradas para que la información sea visualmente limpia y fácil de leer.
  * Si comparas datos, puedes usar tablas simples en Markdown.

ESTADO FINANCIERO ACTUAL DEL USUARIO:
[Configuración Global de la App]
$settingsInfo

[Cuentas y Tarjetas Registradas]
$accountsInfo
Total Global Consolidado: $totalBalance $currency

[Resumen Financiero - Últimos 30 Días]
- Total Ingresos: ${income30.toFormattedString(2)} $currency
- Total Gastos: ${expense30.toFormattedString(2)} $currency
${(income30 - expense30) >= 0 ? '- Balance Neto: +${(income30 - expense30).toFormattedString(2)} $currency (Superávit 🎉)' : '- Balance Neto: -${(expense30 - income30).toFormattedString(2)} $currency (Déficit ⚠️)'}

[Transacciones Recientes (Últimas 50)]
$recentTx

[Categorías Registradas]
${categories.map((c) => c.name).join(', ')}

DIRECTRICES DE RESPUESTA:
1. DIAGNÓSTICO INTUITIVO: Si preguntan "¿cómo voy?" o "¿cuánto he gastado?", analiza con precisión los números y explica de forma clara y cordial la situación actual.
2. CONSEJOS AMIGABLES Y ACCIONABLES: Brinda siempre recomendaciones realistas y sugerencias de ahorro personalizadas según sus categorías de mayor consumo.
3. DETALLES PUNTUALES: Si consultan por una transacción o cuenta específica, cita con exactitud la fecha, monto y concepto.
4. IDIOMA: Responde con total naturalidad en el mismo idioma del usuario (por defecto español).
''';
  }
}
