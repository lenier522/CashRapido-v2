import 'package:hive/hive.dart';

class BusinessExpense {
  final String id;
  final String businessId;
  final double amount;
  final String category; // Rent, Utilities, Supplies, Salaries, etc.
  final String description;
  final String currency;
  final DateTime date;

  BusinessExpense({
    required this.id,
    required this.businessId,
    required this.amount,
    required this.category,
    required this.description,
    required this.currency,
    required this.date,
  });
}

class BusinessExpenseAdapter extends TypeAdapter<BusinessExpense> {
  @override
  final int typeId = 13;

  @override
  BusinessExpense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BusinessExpense(
      id: fields[0] as String,
      businessId: fields[1] as String,
      amount: fields[2] as double,
      category: fields[3] as String,
      description: fields[4] as String,
      currency: fields[5] as String,
      date: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BusinessExpense obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.businessId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.currency)
      ..writeByte(6)
      ..write(obj.date);
  }
}
