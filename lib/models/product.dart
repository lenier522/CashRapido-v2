import 'package:hive/hive.dart';

class Product {
  final String id;
  final String businessId; // Link to Business
  final String name;
  final String description;
  final String sku;

  // Initial Investment Details
  final DateTime investmentDate;
  final double initialQuantity; // Quantity purchased initially (supports decimals e.g. kg/lbs)
  final double costPerUnit; // Cost per unit when purchased
  final String currency;
  final double totalInvestment; // Auto-calculated: initialQuantity * costPerUnit

  // Additional costs (transport, fees, taxes, etc.)
  final double additionalCosts;

  // Current Status
  double currentStock; // Current stock level
  double salePrice; // Selling price per unit
  final String unit; // 'uds', 'kg', 'lb', 'L', 'g'

  // Category and Subcategory Links
  final String? categoryId;
  final String? subcategoryId;

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
    this.additionalCosts = 0.0,
    required this.currentStock,
    required this.salePrice,
    this.unit = 'uds',
    this.categoryId,
    this.subcategoryId,
  });

  // Backward compatibility getters
  double get price => salePrice;
  double get cost => costPerUnit;
  double get stock => currentStock;

  // Real total investment including additional costs
  double get realTotalInvestment => totalInvestment + additionalCosts;

  // Real cost per unit considering additional costs
  double get realCostPerUnit =>
      initialQuantity > 0 ? realTotalInvestment / initialQuantity : costPerUnit;

  // Real profit margin per unit (salePrice - realCostPerUnit)
  double get realProfitMargin => salePrice - realCostPerUnit;

  // Units needed to break even (recover real total investment)
  double get breakEvenUnits =>
      salePrice > 0 ? (realTotalInvestment / salePrice) : 0;

  // Revenue needed to break even
  double get breakEvenRevenue => breakEvenUnits * salePrice;

  // Can break even with current stock?
  bool get canBreakEven => breakEvenUnits <= initialQuantity;

  // Profit after selling all stock
  double get profitAfterAllSold => (salePrice * initialQuantity) - realTotalInvestment;

  // Profit margin percentage
  double get profitMarginPercentage =>
      costPerUnit > 0 ? ((salePrice - costPerUnit) / costPerUnit) * 100 : 0;

  Product copyWith({
    String? id,
    String? businessId,
    String? name,
    String? description,
    String? sku,
    DateTime? investmentDate,
    double? initialQuantity,
    double? costPerUnit,
    String? currency,
    double? totalInvestment,
    double? additionalCosts,
    double? currentStock,
    double? salePrice,
    String? unit,
    String? categoryId,
    String? subcategoryId,
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
      additionalCosts: additionalCosts ?? this.additionalCosts,
      currentStock: currentStock ?? this.currentStock,
      salePrice: salePrice ?? this.salePrice,
      unit: unit ?? this.unit,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
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
      initialQuantity: (fields[6] as num?)?.toDouble() ?? 0.0,
      costPerUnit: (fields[7] as num?)?.toDouble() ?? 0.0,
      currency: fields[8] as String? ?? 'CUP',
      totalInvestment: (fields[9] as num?)?.toDouble() ?? 0.0,
      currentStock: (fields[10] as num?)?.toDouble() ?? 0.0,
      salePrice: (fields[11] as num?)?.toDouble() ?? 0.0,
      additionalCosts: (fields[12] as num?)?.toDouble() ?? 0.0,
      unit: fields[13] as String? ?? 'uds',
      categoryId: fields[14] as String?,
      subcategoryId: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeByte(16) // Number of fields (added unit, categoryId, subcategoryId)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.businessId)
      ..writeByte(2)..write(obj.name)
      ..writeByte(3)..write(obj.description)
      ..writeByte(4)..write(obj.sku)
      ..writeByte(5)..write(obj.investmentDate)
      ..writeByte(6)..write(obj.initialQuantity)
      ..writeByte(7)..write(obj.costPerUnit)
      ..writeByte(8)..write(obj.currency)
      ..writeByte(9)..write(obj.totalInvestment)
      ..writeByte(10)..write(obj.currentStock)
      ..writeByte(11)..write(obj.salePrice)
      ..writeByte(12)..write(obj.additionalCosts)
      ..writeByte(13)..write(obj.unit)
      ..writeByte(14)..write(obj.categoryId)
      ..writeByte(15)..write(obj.subcategoryId);
  }
}
