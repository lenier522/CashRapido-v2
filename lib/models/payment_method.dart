class PaymentMethod {
  final String id;
  final String name;
  final String
  iconAsset; // Can be a local asset path or we'll use Icons for now if needed.
  // Actually user asked for "Apklis, Transfermovil, Enzona, Prueba"
  // I will assume simple icon placeholders or standard Icons for now, or just text if assets missing.
  // To make it robust, I'll store an IconData? or asset path.
  // Let's stick to name for now and maybe a generic type.
  final bool isEnabled;
  final bool isVisible;
  final bool isTest; // To identify "Prueba" easily

  PaymentMethod({
    required this.id,
    required this.name,
    required this.iconAsset,
    this.isEnabled = true,
    this.isVisible = true,
    this.isTest = false,
  });
}
