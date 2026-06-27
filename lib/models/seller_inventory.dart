import 'package:hive/hive.dart';

class SellerInventory {
  final String id;
  final String businessId;
  final String sellerId;
  final String productId;
  final String productName;
  final double assignedQuantity;

  SellerInventory({
    required this.id,
    required this.businessId,
    required this.sellerId,
    required this.productId,
    required this.productName,
    required this.assignedQuantity,
  });
}

class SellerInventoryAdapter extends TypeAdapter<SellerInventory> {
  @override
  final int typeId = 32;

  @override
  SellerInventory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SellerInventory(
      id: fields[0] as String,
      businessId: fields[1] as String,
      sellerId: fields[2] as String,
      productId: fields[3] as String,
      productName: fields[4] as String,
      assignedQuantity: (fields[5] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  void write(BinaryWriter writer, SellerInventory obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.businessId)
      ..writeByte(2)
      ..write(obj.sellerId)
      ..writeByte(3)
      ..write(obj.productId)
      ..writeByte(4)
      ..write(obj.productName)
      ..writeByte(5)
      ..write(obj.assignedQuantity);
  }
}
