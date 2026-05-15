import 'package:hive/hive.dart';

class Sale {
  final String id;
  final String businessId;
  final List<SaleItem> items;
  final double total;
  final String paymentMethod; // Cash, Card, Transfer, etc.
  final DateTime date;
  
  // New features
  final double discount; // Amount discounted
  final String? clientName; // For credit sales
  final String status; // 'paid', 'pending'

  Sale({
    required this.id,
    required this.businessId,
    required this.items,
    required this.total,
    required this.paymentMethod,
    required this.date,
    this.discount = 0.0,
    this.clientName,
    this.status = 'paid',
  });
}

class SaleItem {
  final String productId;
  final String productName; // Store name for historical records
  final int quantity;
  final double unitPrice;
  final double subtotal; // quantity * unitPrice

  SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });
}

class SaleAdapter extends TypeAdapter<Sale> {
  @override
  final int typeId = 11;

  @override
  Sale read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Sale(
      id: fields[0] as String,
      businessId: fields[1] as String,
      items: (fields[2] as List).cast<SaleItem>(),
      total: fields[3] as double,
      paymentMethod: fields[4] as String,
      date: fields[5] as DateTime,
      discount: fields[6] as double? ?? 0.0,
      clientName: fields[7] as String?,
      status: fields[8] as String? ?? 'paid',
    );
  }

  @override
  void write(BinaryWriter writer, Sale obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.businessId)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.total)
      ..writeByte(4)
      ..write(obj.paymentMethod)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.discount)
      ..writeByte(7)
      ..write(obj.clientName)
      ..writeByte(8)
      ..write(obj.status);
  }
}

class SaleItemAdapter extends TypeAdapter<SaleItem> {
  @override
  final int typeId = 12;

  @override
  SaleItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaleItem(
      productId: fields[0] as String,
      productName: fields[1] as String,
      quantity: fields[2] as int,
      unitPrice: fields[3] as double,
      subtotal: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, SaleItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.productName)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.unitPrice)
      ..writeByte(4)
      ..write(obj.subtotal);
  }
}
