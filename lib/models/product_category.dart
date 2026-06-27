import 'package:hive/hive.dart';

@HiveType(typeId: 22)
class ProductCategory extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String businessId;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String? parentId; // If null, it's a category. If not null, it's a subcategory.

  ProductCategory({
    required this.id,
    required this.businessId,
    required this.name,
    this.parentId,
  });
}

class ProductCategoryAdapter extends TypeAdapter<ProductCategory> {
  @override
  final int typeId = 22;

  @override
  ProductCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductCategory(
      id: fields[0] as String,
      businessId: fields[1] as String? ?? '',
      name: fields[2] as String,
      parentId: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductCategory obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.businessId)
      ..writeByte(2)..write(obj.name)
      ..writeByte(3)..write(obj.parentId);
  }
}
