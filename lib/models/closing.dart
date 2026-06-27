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

  // Detailed metrics
  final int salesCount;
  final int expensesCount;
  final String soldProductsJson;
  final String addedProductsJson;
  final String bestSellerName;
  final int bestSellerQty;
  final String paymentMethodsJson;
  final String expenseCategoriesJson;
  final double totalDiscounts;
  final String sellerStatsJson;
  final double costOfGoodsSold;
  final double netProfit;

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
    this.salesCount = 0,
    this.expensesCount = 0,
    this.soldProductsJson = '[]',
    this.addedProductsJson = '[]',
    this.bestSellerName = '',
    this.bestSellerQty = 0,
    this.paymentMethodsJson = '{}',
    this.expenseCategoriesJson = '{}',
    this.totalDiscounts = 0.0,
    this.sellerStatsJson = '{}',
    this.costOfGoodsSold = 0.0,
    this.netProfit = 0.0,
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
      salesCount: fields[9] as int? ?? 0,
      expensesCount: fields[10] as int? ?? 0,
      soldProductsJson: fields[11] as String? ?? '[]',
      addedProductsJson: fields[12] as String? ?? '[]',
      bestSellerName: fields[13] as String? ?? '',
      bestSellerQty: fields[14] as int? ?? 0,
      paymentMethodsJson: fields[15] as String? ?? '{}',
      expenseCategoriesJson: fields[16] as String? ?? '{}',
      totalDiscounts: fields[17] as double? ?? 0.0,
      sellerStatsJson: fields[18] as String? ?? '{}',
      costOfGoodsSold: (fields[19] as num?)?.toDouble() ?? 0.0,
      netProfit: (fields[20] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  void write(BinaryWriter writer, Closing obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.businessId)
      ..writeByte(2)..write(obj.period)
      ..writeByte(3)..write(obj.startDate)
      ..writeByte(4)..write(obj.endDate)
      ..writeByte(5)..write(obj.income)
      ..writeByte(6)..write(obj.expenses)
      ..writeByte(7)..write(obj.profit)
      ..writeByte(8)..write(obj.roi)
      ..writeByte(9)..write(obj.salesCount)
      ..writeByte(10)..write(obj.expensesCount)
      ..writeByte(11)..write(obj.soldProductsJson)
      ..writeByte(12)..write(obj.addedProductsJson)
      ..writeByte(13)..write(obj.bestSellerName)
      ..writeByte(14)..write(obj.bestSellerQty)
      ..writeByte(15)..write(obj.paymentMethodsJson)
      ..writeByte(16)..write(obj.expenseCategoriesJson)
      ..writeByte(17)..write(obj.totalDiscounts)
      ..writeByte(18)..write(obj.sellerStatsJson)
      ..writeByte(19)..write(obj.costOfGoodsSold)
      ..writeByte(20)..write(obj.netProfit);
  }
}
