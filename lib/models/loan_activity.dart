import 'package:hive/hive.dart';

class LoanActivity {
  final String id;
  final String loanId;
  final DateTime timestamp;
  final String action;
  final String description;

  LoanActivity({
    required this.id,
    required this.loanId,
    required this.timestamp,
    required this.action,
    required this.description,
  });
}

class LoanActivityAdapter extends TypeAdapter<LoanActivity> {
  @override
  final int typeId = 29;

  @override
  LoanActivity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LoanActivity(
      id: fields[0] as String,
      loanId: fields[1] as String,
      timestamp: fields[2] as DateTime,
      action: fields[3] as String,
      description: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, LoanActivity obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.loanId)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.action)
      ..writeByte(4)
      ..write(obj.description);
  }
}
