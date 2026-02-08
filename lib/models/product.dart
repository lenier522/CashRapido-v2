import 'package:hive/hive.dart';

class Product {
  final String id;
  final String businessId; // Link to Business
  final String name;
  final String description;
  final String sku;

  // Initial Investment Details
  final DateTime investmentDate;
  final int initialQuantity; // Quantity purchased initially
  final double costPerUnit; // Cost per unit when purchased
  final String currency;
  final double
  totalInvestment; // Auto-calculated: initialQuantity * costPerUnit

  // Current Status
  int currentStock; // Current stock level
  double salePrice; // Selling price per unit

  Product({
    required this.id,
    required this.businessId,
    required this.name,
    required this.description,
    required this.sku,
    required this.investmentDate,
    required this.initialQuantity,
    required this.costPerUnit,
    required this.currency,
    required this.totalInvestment,
    required this.currentStock,
    required this.salePrice,
  });

  // Backward compatibility getters
  double get price => salePrice;
  double get cost => costPerUnit;
  int get stock => currentStock;

  // Helper: Calculate profit margin
  double get profitMargin => salePrice - costPerUnit;

  // Helper: Calculate profit margin percentage
  double get profitMarginPercentage =>
      costPerUnit > 0 ? ((profitMargin / costPerUnit) * 100) : 0;

  Product copyWith({
    String? id,
    String? businessId,
    String? name,
    String? description,
    String? sku,
    DateTime? investmentDate,
    int? initialQuantity,
    double? costPerUnit,
    String? currency,
    double? totalInvestment,
    int? currentStock,
    double? salePrice,
  }) {
    return Product(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      investmentDate: investmentDate ?? this.investmentDate,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      currency: currency ?? this.currency,
      totalInvestment: totalInvestment ?? this.totalInvestment,
      currentStock: currentStock ?? this.currentStock,
      salePrice: salePrice ?? this.salePrice,
    );
  }
}

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 3; // Keep existing ID

  @override
  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Product(
      id: fields[0] as String,
      businessId: fields[1] as String? ?? '', // Default for old data
      name: fields[2] as String,
      description: fields[3] as String? ?? '',
      sku: fields[4] as String? ?? '',
      investmentDate: fields[5] as DateTime? ?? DateTime.now(),
      initialQuantity: fields[6] as int? ?? 0,
      costPerUnit: fields[7] as double? ?? 0.0,
      currency: fields[8] as String? ?? 'CUP',
      totalInvestment: fields[9] as double? ?? 0.0,
      currentStock: fields[10] as int? ?? 0,
      salePrice: fields[11] as double? ?? 0.0,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeByte(12) // Number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.businessId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.sku)
      ..writeByte(5)
      ..write(obj.investmentDate)
      ..writeByte(6)
      ..write(obj.initialQuantity)
      ..writeByte(7)
      ..write(obj.costPerUnit)
      ..writeByte(8)
      ..write(obj.currency)
      ..writeByte(9)
      ..write(obj.totalInvestment)
      ..writeByte(10)
      ..write(obj.currentStock)
      ..writeByte(11)
      ..write(obj.salePrice);
  }
}
