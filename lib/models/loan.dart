import 'package:hive/hive.dart';

class Loan {
  final String id;
  final String borrowerName;
  final double amount;
  final double interestRate;
  final String interestType; // 'simple', 'compound', 'fixed'
  final String frequency; // 'daily', 'weekly', 'monthly', 'single'
  final int durationValue;
  final DateTime startDate;
  final DateTime dueDate;
  final bool isNotificationsEnabled;
  final String? notes;
  double remainingAmount;
  String status; // 'active', 'paid', 'overdue', 'written_off', 'refinanced'
  final String? cardId; // Optional wallet card ID used for funding the loan
  final String currency; // Currency code ('CUP', 'USD', 'EUR', etc.)

  // Advanced suite fields (backwards-compatible)
  final String? borrowerId; // Link to Borrower model in Hive
  final String lateFeeType; // 'none', 'fixed', 'percent'
  final double lateFeeValue; // Value of penalty fee
  final DateTime? lastMoraAppliedDate; // Last time a daily penalty fee was applied
  final List<Installment> installments; // Schedule of installments

  Loan({
    required this.id,
    required this.borrowerName,
    required this.amount,
    required this.interestRate,
    required this.interestType,
    required this.frequency,
    required this.durationValue,
    required this.startDate,
    required this.dueDate,
    required this.isNotificationsEnabled,
    this.notes,
    required this.remainingAmount,
    required this.status,
    this.cardId,
    required this.currency,
    this.borrowerId,
    this.lateFeeType = 'none',
    this.lateFeeValue = 0.0,
    this.lastMoraAppliedDate,
    this.installments = const [],
  });

  Loan copyWith({
    String? id,
    String? borrowerName,
    double? amount,
    double? interestRate,
    String? interestType,
    String? frequency,
    int? durationValue,
    DateTime? startDate,
    DateTime? dueDate,
    bool? isNotificationsEnabled,
    String? notes,
    double? remainingAmount,
    String? status,
    String? cardId,
    String? currency,
    String? borrowerId,
    String? lateFeeType,
    double? lateFeeValue,
    DateTime? lastMoraAppliedDate,
    List<Installment>? installments,
  }) {
    return Loan(
      id: id ?? this.id,
      borrowerName: borrowerName ?? this.borrowerName,
      amount: amount ?? this.amount,
      interestRate: interestRate ?? this.interestRate,
      interestType: interestType ?? this.interestType,
      frequency: frequency ?? this.frequency,
      durationValue: durationValue ?? this.durationValue,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      isNotificationsEnabled: isNotificationsEnabled ?? this.isNotificationsEnabled,
      notes: notes ?? this.notes,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      status: status ?? this.status,
      cardId: cardId ?? this.cardId,
      currency: currency ?? this.currency,
      borrowerId: borrowerId ?? this.borrowerId,
      lateFeeType: lateFeeType ?? this.lateFeeType,
      lateFeeValue: lateFeeValue ?? this.lateFeeValue,
      lastMoraAppliedDate: lastMoraAppliedDate ?? this.lastMoraAppliedDate,
      installments: installments ?? this.installments,
    );
  }
}

class LoanAdapter extends TypeAdapter<Loan> {
  @override
  final int typeId = 25;

  @override
  Loan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    final installmentsRaw = fields[19] as List<dynamic>?;
    final installments = installmentsRaw != null
        ? List<Installment>.from(installmentsRaw)
        : <Installment>[];

    return Loan(
      id: fields[0] as String,
      borrowerName: fields[1] as String,
      amount: fields[2] as double,
      interestRate: fields[3] as double,
      interestType: fields[4] as String,
      frequency: fields[5] as String,
      durationValue: fields[6] as int,
      startDate: fields[7] as DateTime,
      dueDate: fields[8] as DateTime,
      isNotificationsEnabled: fields[9] as bool,
      notes: fields[10] as String?,
      remainingAmount: fields[11] as double,
      status: fields[12] as String,
      cardId: fields[13] as String?,
      currency: fields[14] as String,
      borrowerId: fields[15] as String?,
      lateFeeType: (fields[16] as String?) ?? 'none',
      lateFeeValue: (fields[17] as double?) ?? 0.0,
      lastMoraAppliedDate: fields[18] as DateTime?,
      installments: installments,
    );
  }

  @override
  void write(BinaryWriter writer, Loan obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.borrowerName)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.interestRate)
      ..writeByte(4)
      ..write(obj.interestType)
      ..writeByte(5)
      ..write(obj.frequency)
      ..writeByte(6)
      ..write(obj.durationValue)
      ..writeByte(7)
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.dueDate)
      ..writeByte(9)
      ..write(obj.isNotificationsEnabled)
      ..writeByte(10)
      ..write(obj.notes)
      ..writeByte(11)
      ..write(obj.remainingAmount)
      ..writeByte(12)
      ..write(obj.status)
      ..writeByte(13)
      ..write(obj.cardId)
      ..writeByte(14)
      ..write(obj.currency)
      ..writeByte(15)
      ..write(obj.borrowerId)
      ..writeByte(16)
      ..write(obj.lateFeeType)
      ..writeByte(17)
      ..write(obj.lateFeeValue)
      ..writeByte(18)
      ..write(obj.lastMoraAppliedDate)
      ..writeByte(19)
      ..write(obj.installments);
  }
}

class LoanPayment {
  final String id;
  final String loanId;
  final double amount;
  final DateTime date;
  final String? notes;
  final String? cardId; // Optional wallet card ID credited with the payment
  final List<int>? affectedInstallmentNumbers; // Installment numbers covered by this payment

  LoanPayment({
    required this.id,
    required this.loanId,
    required this.amount,
    required this.date,
    this.notes,
    this.cardId,
    this.affectedInstallmentNumbers,
  });
}

class LoanPaymentAdapter extends TypeAdapter<LoanPayment> {
  @override
  final int typeId = 26;

  @override
  LoanPayment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    final affectedRaw = fields[6] as List<dynamic>?;
    final affectedInstallmentNumbers = affectedRaw != null ? List<int>.from(affectedRaw) : <int>[];

    return LoanPayment(
      id: fields[0] as String,
      loanId: fields[1] as String,
      amount: fields[2] as double,
      date: fields[3] as DateTime,
      notes: fields[4] as String?,
      cardId: fields[5] as String?,
      affectedInstallmentNumbers: affectedInstallmentNumbers,
    );
  }

  @override
  void write(BinaryWriter writer, LoanPayment obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.loanId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.cardId)
      ..writeByte(6)
      ..write(obj.affectedInstallmentNumbers ?? <int>[]);
  }
}

class Installment {
  final int number;
  final DateTime dueDate;
  final double amount;
  final double paidAmount;
  final String status; // 'pending', 'paid', 'partial', 'overdue'

  Installment({
    required this.number,
    required this.dueDate,
    required this.amount,
    required this.paidAmount,
    required this.status,
  });

  double get remainingAmount => amount - paidAmount;

  Installment copyWith({
    int? number,
    DateTime? dueDate,
    double? amount,
    double? paidAmount,
    String? status,
  }) {
    return Installment(
      number: number ?? this.number,
      dueDate: dueDate ?? this.dueDate,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
    );
  }
}

class InstallmentAdapter extends TypeAdapter<Installment> {
  @override
  final int typeId = 28;

  @override
  Installment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Installment(
      number: fields[0] as int,
      dueDate: fields[1] as DateTime,
      amount: fields[2] as double,
      paidAmount: fields[3] as double,
      status: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Installment obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.number)
      ..writeByte(1)
      ..write(obj.dueDate)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.paidAmount)
      ..writeByte(4)
      ..write(obj.status);
  }
}
