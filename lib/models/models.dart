import 'package:hive/hive.dart';

part 'models.g.dart';

/// Valores permitidos para `Category.type`.
///
/// Es la única fuente de verdad de la clasificación: se guarda en Hive como
/// `String` para que los datos sean legibles y compatibles con cualquier
/// versión anterior. Cualquier valor desconocido se normaliza a [both], que
/// es además el valor de respaldo para las categorías antiguas creadas antes
/// de existir este campo.
class CategoryTypes {
  static const String expense = 'expense';
  static const String income = 'income';
  static const String both = 'both';

  static const List<String> values = <String>[expense, income, both];

  /// Convierte cualquier valor almacenado en uno de los tres soportados.
  static String normalize(String? value) =>
      values.contains(value) ? value! : both;

  /// `true` si la categoría de [type] puede usarse en el flujo indicado.
  ///
  /// [isExpense] `true` para gastos, `false` para ingresos.
  static bool allows(String? type, {required bool isExpense}) {
    final String normalized = normalize(type);
    if (normalized == both) return true;
    return isExpense ? normalized == expense : normalized == income;
  }
}

@HiveType(typeId: 0)
class Category extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int iconCode; // Store IconData.codePoint

  @HiveField(3)
  final int colorValue; // Store Color.value

  @HiveField(4)
  final bool isCustom;

  @HiveField(5)
  final double? monthlyBudget;

  /// Clasificación: `expense`, `income` o `both`.
  ///
  /// Índice Hive nuevo (6): no toca los campos 0-5 que ya contienen datos de
  /// usuarios reales. Las categorías guardadas sin este campo se leen como
  /// [CategoryTypes.both], de modo que siguen apareciendo en gastos e ingresos
  /// igual que antes.
  @HiveField(6, defaultValue: CategoryTypes.both)
  final String type;

  Category({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.colorValue,
    this.isCustom = false,
    this.monthlyBudget,
    this.type = CategoryTypes.both,
  });
}

@HiveType(typeId: 1)
class InternalTransaction extends HiveObject {
  // Renamed to avoid key formatting conflict with 'Transaction' generic
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final String currency; // 'CUP', 'USD', 'EUR'

  @HiveField(3)
  final String categoryId;

  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  final String title;

  @HiveField(6) // Adjusted HiveField index to avoid conflict with 'title'
  final String? cardId; // Optional link to specific card

  InternalTransaction({
    required this.id,
    required this.amount,
    required this.currency,
    required this.categoryId,
    required this.date,
    required this.title,
    this.cardId,
  });
}

/// Tipos de cuenta/billetera permitidos en la app.
class AccountTypes {
  static const String current = 'current'; // Cuenta Corriente
  static const String savings = 'savings'; // Ahorros
  static const String creditCard = 'credit_card'; // Tarjeta de Crédito
  static const String cash = 'cash'; // Efectivo
  static const String other = 'other'; // Otros

  static const List<String> values = <String>[
    current,
    savings,
    creditCard,
    cash,
    other,
  ];

  static String normalize(String? value) {
    if (value == null || value.isEmpty) return current;
    if (values.contains(value)) return value;
    // Compatibilidad con valores antiguos
    if (value == 'checking') return current;
    if (value == 'wallet' || value == 'efectivo') return cash;
    return current;
  }
}

@HiveType(typeId: 2)
class AccountCard extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double balance;

  @HiveField(3)
  final String currency;

  @HiveField(4)
  final String cardNumber; // Last 4 digits or full masked

  @HiveField(5)
  final String expiryDate;

  @HiveField(6)
  final int colorValue;

  @HiveField(7)
  final bool isLocked;

  @HiveField(8)
  final String? pin;

  @HiveField(9)
  final double? spendingLimit;

  @HiveField(10)
  final String? bankName;

  @HiveField(11, defaultValue: false)
  final bool isCash;

  /// Tipo de cuenta: current | savings | credit_card | cash | other
  @HiveField(12, defaultValue: AccountTypes.current)
  final String accountType;

  // --- Ahorros con rendimiento ---
  @HiveField(13, defaultValue: false)
  final bool interestEnabled;

  @HiveField(14)
  final double? interestRateEA; // Tasa EA (%)

  /// frecuencia de rendimiento: daily | monthly | yearly
  @HiveField(15)
  final String? interestFrequency;

  @HiveField(16)
  final DateTime? nextInterestAt; // Próximo rendimiento (fecha y hora)

  // --- Tarjeta de crédito ---
  @HiveField(17)
  final double? creditLimit;

  @HiveField(18)
  final int? cutoffDay; // Día de corte

  @HiveField(19)
  final int? paymentDueDay; // Día de pago

  @HiveField(20)
  final double? annualInterestRate; // Tasa de interés anual (%)

  @HiveField(21)
  final double? monthlyManagementFee; // Cuota de manejo mensual

  AccountCard({
    required this.id,
    required this.name,
    required this.balance,
    required this.currency,
    required this.cardNumber,
    required this.expiryDate,
    required this.colorValue,
    this.isLocked = false,
    this.pin,
    this.spendingLimit,
    this.bankName,
    this.isCash = false,
    String? accountType,
    this.interestEnabled = false,
    this.interestRateEA,
    this.interestFrequency,
    this.nextInterestAt,
    this.creditLimit,
    this.cutoffDay,
    this.paymentDueDay,
    this.annualInterestRate,
    this.monthlyManagementFee,
  }) : accountType = AccountTypes.normalize(accountType ?? (isCash ? AccountTypes.cash : AccountTypes.current));

  AccountCard copyWith({
    String? id,
    String? name,
    double? balance,
    String? currency,
    String? cardNumber,
    String? expiryDate,
    int? colorValue,
    bool? isLocked,
    String? pin,
    double? spendingLimit,
    String? bankName,
    bool? isCash,
    String? accountType,
    bool? interestEnabled,
    double? interestRateEA,
    String? interestFrequency,
    DateTime? nextInterestAt,
    bool clearNextInterestAt = false,
    double? creditLimit,
    bool clearCreditLimit = false,
    int? cutoffDay,
    bool clearCutoffDay = false,
    int? paymentDueDay,
    bool clearPaymentDueDay = false,
    double? annualInterestRate,
    bool clearAnnualInterestRate = false,
    double? monthlyManagementFee,
    bool clearMonthlyManagementFee = false,
  }) {
    return AccountCard(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      cardNumber: cardNumber ?? this.cardNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      colorValue: colorValue ?? this.colorValue,
      isLocked: isLocked ?? this.isLocked,
      pin: pin ?? this.pin,
      spendingLimit: spendingLimit ?? this.spendingLimit,
      bankName: bankName ?? this.bankName,
      isCash: isCash ?? this.isCash,
      accountType: AccountTypes.normalize(accountType ?? this.accountType),
      interestEnabled: interestEnabled ?? this.interestEnabled,
      interestRateEA: interestRateEA ?? this.interestRateEA,
      interestFrequency: interestFrequency ?? this.interestFrequency,
      nextInterestAt: clearNextInterestAt ? null : (nextInterestAt ?? this.nextInterestAt),
      creditLimit: clearCreditLimit ? null : (creditLimit ?? this.creditLimit),
      cutoffDay: clearCutoffDay ? null : (cutoffDay ?? this.cutoffDay),
      paymentDueDay: clearPaymentDueDay ? null : (paymentDueDay ?? this.paymentDueDay),
      annualInterestRate: clearAnnualInterestRate ? null : (annualInterestRate ?? this.annualInterestRate),
      monthlyManagementFee: clearMonthlyManagementFee ? null : (monthlyManagementFee ?? this.monthlyManagementFee),
    );
  }

  bool get isSavingsAccount => AccountTypes.normalize(accountType) == AccountTypes.savings;
  bool get isCreditCardAccount => AccountTypes.normalize(accountType) == AccountTypes.creditCard;
  bool get isCurrentAccount => AccountTypes.normalize(accountType) == AccountTypes.current;
  bool get isOtherAccount => AccountTypes.normalize(accountType) == AccountTypes.other;
}

class Currency {
  final String code;
  final String symbol;
  final String name;

  Currency({required this.code, required this.symbol, required this.name});

  Map<String, dynamic> toJson() {
    return {'code': code, 'symbol': symbol, 'name': name};
  }

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      code: json['code'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
    );
  }
}

@HiveType(typeId: 15)
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String role; // 'user' or 'model'

  @HiveField(1)
  final String text;

  @HiveField(2)
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });
}

@HiveType(typeId: 16)
class ChatConversation extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  DateTime updatedAt;

  @HiveField(4)
  final List<ChatMessage> messages;

  ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });
}
