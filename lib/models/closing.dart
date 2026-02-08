import 'package:hive/hive.dart';

class Closing {
  final String id;
  final String businessId;
  final String period; // daily, weekly, monthly, yearly
  final DateTime startDate;
  final DateTime endDate;
  final double income;
  final double expenses;
  final double profit; // income - expenses
  final double roi; // Return on Investment percentage

  Closing({
    required this.id,
    required this.businessId,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.income,
    required this.expenses,
    required this.profit,
    required this.roi,
  });
}

class ClosingAdapter extends TypeAdapter<Closing> {
  @override
  final int typeId = 14;

  @override
  Closing read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Closing(
      id: fields[0] as String,
      businessId: fields[1] as String,
      period: fields[2] as String,
      startDate: fields[3] as DateTime,
      endDate: fields[4] as DateTime,
      income: fields[5] as double,
      expenses: fields[6] as double,
      profit: fields[7] as double,
      roi: fields[8] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Closing obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.businessId)
      ..writeByte(2)
      ..write(obj.period)
      ..writeByte(3)
      ..write(obj.startDate)
      ..writeByte(4)
      ..write(obj.endDate)
      ..writeByte(5)
      ..write(obj.income)
      ..writeByte(6)
      ..write(obj.expenses)
      ..writeByte(7)
      ..write(obj.profit)
      ..writeByte(8)
      ..write(obj.roi);
  }
}
