import 'package:hive/hive.dart';

class Borrower extends HiveObject {
  final String id;
  final String name;
  final String lastName;
  final String phone;
  final String address;
  final String? writtenLocation;
  final String riskLevel; // 'low', 'medium', 'high'
  final String? localPhotoPath;
  final String? personalReference;
  final String? notes;
  final DateTime registrationDate;

  Borrower({
    required this.id,
    required this.name,
    required this.lastName,
    required this.phone,
    required this.address,
    this.writtenLocation,
    required this.riskLevel,
    this.localPhotoPath,
    this.personalReference,
    this.notes,
    required this.registrationDate,
  });

  String get fullName => '$name $lastName'.trim();

  Borrower copyWith({
    String? id,
    String? name,
    String? lastName,
    String? phone,
    String? address,
    String? writtenLocation,
    String? riskLevel,
    String? localPhotoPath,
    String? personalReference,
    String? notes,
    DateTime? registrationDate,
  }) {
    return Borrower(
      id: id ?? this.id,
      name: name ?? this.name,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      writtenLocation: writtenLocation ?? this.writtenLocation,
      riskLevel: riskLevel ?? this.riskLevel,
      localPhotoPath: localPhotoPath ?? this.localPhotoPath,
      personalReference: personalReference ?? this.personalReference,
      notes: notes ?? this.notes,
      registrationDate: registrationDate ?? this.registrationDate,
    );
  }
}

class BorrowerAdapter extends TypeAdapter<Borrower> {
  @override
  final int typeId = 27;

  @override
  Borrower read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Borrower(
      id: fields[0] as String,
      name: fields[1] as String,
      lastName: fields[2] as String,
      phone: fields[3] as String,
      address: fields[4] as String,
      writtenLocation: fields[5] as String?,
      riskLevel: fields[6] as String,
      localPhotoPath: fields[7] as String?,
      personalReference: fields[8] as String?,
      notes: fields[9] as String?,
      registrationDate: fields[10] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Borrower obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.lastName)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.address)
      ..writeByte(5)
      ..write(obj.writtenLocation)
      ..writeByte(6)
      ..write(obj.riskLevel)
      ..writeByte(7)
      ..write(obj.localPhotoPath)
      ..writeByte(8)
      ..write(obj.personalReference)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.registrationDate);
  }
}
