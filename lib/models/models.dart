import 'package:hive/hive.dart';

part 'models.g.dart';

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

  Category({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.colorValue,
    this.isCustom = false,
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
  });

  @HiveField(10)
  final String? bankName;
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
