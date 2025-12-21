// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CategoryAdapter extends TypeAdapter<Category> {
  @override
  final int typeId = 0;

  @override
  Category read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Category(
      id: fields[0] as String,
      name: fields[1] as String,
      iconCode: fields[2] as int,
      colorValue: fields[3] as int,
      isCustom: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Category obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.iconCode)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.isCustom);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InternalTransactionAdapter extends TypeAdapter<InternalTransaction> {
  @override
  final int typeId = 1;

  @override
  InternalTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InternalTransaction(
      id: fields[0] as String,
      amount: fields[1] as double,
      currency: fields[2] as String,
      categoryId: fields[3] as String,
      date: fields[4] as DateTime,
      title: fields[5] as String,
      cardId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, InternalTransaction obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.currency)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.title)
      ..writeByte(6)
      ..write(obj.cardId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InternalTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AccountCardAdapter extends TypeAdapter<AccountCard> {
  @override
  final int typeId = 2;

  @override
  AccountCard read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AccountCard(
      id: fields[0] as String,
      name: fields[1] as String,
      balance: fields[2] as double,
      currency: fields[3] as String,
      cardNumber: fields[4] as String,
      expiryDate: fields[5] as String,
      colorValue: fields[6] as int,
      isLocked: fields[7] as bool,
      pin: fields[8] as String?,
      spendingLimit: fields[9] as double?,
      bankName: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AccountCard obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.balance)
      ..writeByte(3)
      ..write(obj.currency)
      ..writeByte(4)
      ..write(obj.cardNumber)
      ..writeByte(5)
      ..write(obj.expiryDate)
      ..writeByte(6)
      ..write(obj.colorValue)
      ..writeByte(7)
      ..write(obj.isLocked)
      ..writeByte(8)
      ..write(obj.pin)
      ..writeByte(9)
      ..write(obj.spendingLimit)
      ..writeByte(10)
      ..write(obj.bankName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountCardAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
