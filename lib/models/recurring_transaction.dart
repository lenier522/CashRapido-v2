import 'package:hive/hive.dart';

part 'recurring_transaction.g.dart';

@HiveType(typeId: 20)
class RecurringTransaction extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final double amount;

  @HiveField(4)
  final String categoryId;

  @HiveField(5)
  final String accountId;

  @HiveField(6)
  final DateTime nextExecutionDate;

  @HiveField(7)
  final String recurrence; // 'diario', 'semanal', 'quincenal', 'mensual', 'trimestral', 'anual'

  @HiveField(8)
  final bool autoRegister;

  @HiveField(9)
  final bool isIncome;

  RecurringTransaction({
    required this.id,
    required this.title,
    this.description = '',
    required this.amount,
    required this.categoryId,
    required this.accountId,
    required this.nextExecutionDate,
    required this.recurrence,
    required this.autoRegister,
    this.isIncome = true,
  });

  RecurringTransaction copyWith({
    String? title,
    String? description,
    double? amount,
    String? categoryId,
    String? accountId,
    DateTime? nextExecutionDate,
    String? recurrence,
    bool? autoRegister,
    bool? isIncome,
  }) {
    return RecurringTransaction(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      nextExecutionDate: nextExecutionDate ?? this.nextExecutionDate,
      recurrence: recurrence ?? this.recurrence,
      autoRegister: autoRegister ?? this.autoRegister,
      isIncome: isIncome ?? this.isIncome,
    );
  }
}
