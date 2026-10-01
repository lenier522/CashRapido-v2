import 'package:hive/hive.dart';

class Business {
  final String id;
  String name;
  String type; // Retail, Restaurant, Services, etc.
  String iconCode; // Material icon code name
  int colorValue; // Color as int
  final DateTime createdAt;
  String currency; // Default currency for this business
  double initialCapital; // Initial assigned capital/credit for inventory
  String? linkedCardId; // Linked main card/account

  Business({
    required this.id,
    required this.name,
    required this.type,
    required this.iconCode,
    required this.colorValue,
    required this.createdAt,
    this.currency = 'CUP',
    this.initialCapital = 0.0,
    this.linkedCardId,
  });

  Business copyWith({
    String? id,
    String? name,
    String? type,
    String? iconCode,
    int? colorValue,
    DateTime? createdAt,
    String? currency,
    double? initialCapital,
    String? linkedCardId,
  }) {
    return Business(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      currency: currency ?? this.currency,
      initialCapital: initialCapital ?? this.initialCapital,
      linkedCardId: linkedCardId ?? this.linkedCardId,
    );
  }
}

class BusinessAdapter extends TypeAdapter<Business> {
  @override
  final int typeId = 10;

  @override
  Business read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Business(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      iconCode: fields[3] as String,
      colorValue: fields[4] as int,
      createdAt: fields[5] as DateTime,
      currency: fields[6] as String? ?? 'CUP',
      initialCapital: (fields[7] as num?)?.toDouble() ?? 0.0,
      linkedCardId: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Business obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.iconCode)
      ..writeByte(4)
      ..write(obj.colorValue)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.currency)
      ..writeByte(7)
      ..write(obj.initialCapital)
      ..writeByte(8)
      ..write(obj.linkedCardId);
  }
}
