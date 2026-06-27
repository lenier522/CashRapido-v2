import 'package:hive/hive.dart';

class Seller {
  final String id;
  final String businessId;

  final String name;
  final String lastName;
  final String phone;
  final String email;
  final String ci;
  final String address;

  final String role;
  final double commissionRate;
  final double salary;
  final DateTime hireDate;
  final bool isActive;

  final String notes;

  Seller({
    required this.id,
    required this.businessId,
    required this.name,
    required this.lastName,
    required this.phone,
    this.email = '',
    this.ci = '',
    this.address = '',
    this.role = '',
    this.commissionRate = 0.0,
    this.salary = 0.0,
    required this.hireDate,
    this.isActive = true,
    this.notes = '',
  });

  String get fullName => '$name $lastName';
}

class SellerAdapter extends TypeAdapter<Seller> {
  @override
  final int typeId = 30;

  @override
  Seller read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Seller(
      id: fields[0] as String,
      businessId: fields[1] as String,
      name: fields[2] as String,
      lastName: fields[3] as String,
      phone: fields[4] as String,
      email: fields[5] as String? ?? '',
      ci: fields[6] as String? ?? '',
      address: fields[7] as String? ?? '',
      role: fields[8] as String? ?? '',
      commissionRate: (fields[9] as num?)?.toDouble() ?? 0.0,
      salary: (fields[10] as num?)?.toDouble() ?? 0.0,
      hireDate: fields[11] as DateTime,
      isActive: fields[12] as bool? ?? true,
      notes: fields[13] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, Seller obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.businessId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.lastName)
      ..writeByte(4)
      ..write(obj.phone)
      ..writeByte(5)
      ..write(obj.email)
      ..writeByte(6)
      ..write(obj.ci)
      ..writeByte(7)
      ..write(obj.address)
      ..writeByte(8)
      ..write(obj.role)
      ..writeByte(9)
      ..write(obj.commissionRate)
      ..writeByte(10)
      ..write(obj.salary)
      ..writeByte(11)
      ..write(obj.hireDate)
      ..writeByte(12)
      ..write(obj.isActive)
      ..writeByte(13)
      ..write(obj.notes);
  }
}
