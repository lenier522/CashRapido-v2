import 'package:flutter/material.dart';

/// Opción de icono de negocio del catálogo.
///
/// Almacena la clave estable y el `IconData`; el `codePoint` se obtiene en
/// tiempo de ejecución del propio icono (por eso el catálogo es `static final`
/// y no `const`).
class BusinessIconOption {
  final String key;
  final IconData icon;

  const BusinessIconOption(this.key, this.icon);

  int get codePoint => icon.codePoint;
}

/// Catálogo y resolución de iconos de negocio.
///
/// Las 8 claves legadas (`store`, `restaurant`, `build`, `computer`, `school`,
/// `shopping_cart`, `local_shipping`, `home`) se conservan **exactamente** con
/// sus mismos `codePoint` para no romper datos guardados. El catálogo añade
/// más iconos de negocio sobre la misma mecánica.
class BusinessIconHelper {
  // Mapping of legacy string keys to IconData codePoints
  static const Map<String, IconData> legacyIconsMap = {
    'store': Icons.store,
    'restaurant': Icons.restaurant,
    'build': Icons.build,
    'computer': Icons.computer,
    'school': Icons.school,
    'shopping_cart': Icons.shopping_cart,
    'local_shipping': Icons.local_shipping,
    'home': Icons.home,
  };

  static const Map<String, int> _legacyIconsCodePoints = {
    'store': 0xe5dc, // Icons.store
    'restaurant': 0xe56c, // Icons.restaurant
    'build': 0xe12d, // Icons.build
    'computer': 0xe150, // Icons.computer
    'school': 0xe556, // Icons.school
    'shopping_cart': 0xe59c, // Icons.shopping_cart
    'local_shipping': 0xe3a6, // Icons.local_shipping
    'home': 0xe318, // Icons.home
  };

  static const Map<int, IconData> _codePointToIcon = {
    0xe5dc: Icons.store,
    0xe56c: Icons.restaurant,
    0xe12d: Icons.build,
    0xe150: Icons.computer,
    0xe556: Icons.school,
    0xe59c: Icons.shopping_cart,
    0xe3a6: Icons.local_shipping,
    0xe318: Icons.home,
  };

  /// Catálogo completo de iconos de negocio: los 8 legados + ampliación.
  static final List<BusinessIconOption> catalog = <BusinessIconOption>[
    // Legados (mismos key y codePoint que siempre).
    const BusinessIconOption('store', Icons.store),
    const BusinessIconOption('restaurant', Icons.restaurant),
    const BusinessIconOption('build', Icons.build),
    const BusinessIconOption('computer', Icons.computer),
    const BusinessIconOption('school', Icons.school),
    const BusinessIconOption('shopping_cart', Icons.shopping_cart),
    const BusinessIconOption('local_shipping', Icons.local_shipping),
    const BusinessIconOption('home', Icons.home),
    // Ampliación del catálogo.
    const BusinessIconOption('business_center', Icons.business_center),
    const BusinessIconOption('storefront', Icons.storefront),
    const BusinessIconOption('point_of_sale', Icons.point_of_sale),
    const BusinessIconOption('shopping_bag', Icons.shopping_bag),
    const BusinessIconOption('inventory_2', Icons.inventory_2),
    const BusinessIconOption('category', Icons.category_outlined),
    const BusinessIconOption('sell', Icons.sell),
    const BusinessIconOption('payments', Icons.payments_outlined),
    const BusinessIconOption('account_balance', Icons.account_balance),
    const BusinessIconOption('savings', Icons.savings_outlined),
    const BusinessIconOption('trending_up', Icons.trending_up),
    const BusinessIconOption('bar_chart', Icons.bar_chart),
    const BusinessIconOption('analytics', Icons.analytics_outlined),
    const BusinessIconOption('receipt_long', Icons.receipt_long),
    const BusinessIconOption('credit_card', Icons.credit_card),
    const BusinessIconOption('attach_money', Icons.attach_money),
    const BusinessIconOption('paid', Icons.paid_outlined),
    const BusinessIconOption('rocket_launch', Icons.rocket_launch),
    const BusinessIconOption('handyman', Icons.handyman),
    const BusinessIconOption('construction', Icons.construction),
    const BusinessIconOption('engineering', Icons.engineering),
    const BusinessIconOption('design_services', Icons.design_services),
    const BusinessIconOption('headset_mic', Icons.headset_mic),
    const BusinessIconOption('local_cafe', Icons.local_cafe),
    const BusinessIconOption('fastfood', Icons.fastfood),
    const BusinessIconOption('bakery_dining', Icons.bakery_dining),
    const BusinessIconOption('icecream', Icons.icecream),
    const BusinessIconOption('medical_services', Icons.medical_services),
    const BusinessIconOption('fitness_center', Icons.fitness_center),
    const BusinessIconOption('pets', Icons.pets),
    const BusinessIconOption('checkroom', Icons.checkroom),
    const BusinessIconOption('chair', Icons.chair_outlined),
    const BusinessIconOption('phone_iphone', Icons.phone_iphone),
    const BusinessIconOption('laptop_mac', Icons.laptop_mac),
    const BusinessIconOption('qr_code_scanner', Icons.qr_code_scanner),
  ];

  /// Parses iconCode which can be an integer string (codePoint) or a legacy string key (e.g. 'restaurant')
  /// Returns the correct IconData, defaulting to Icons.store if invalid.
  static IconData getIcon(String iconCode) {
    // 1. Try to parse as integer (New Format: codePoint)
    final int? codePoint = int.tryParse(iconCode);
    if (codePoint != null) {
      if (_codePointToIcon.containsKey(codePoint)) {
        return _codePointToIcon[codePoint]!;
      }
      for (final BusinessIconOption option in catalog) {
        if (option.codePoint == codePoint) return option.icon;
      }
      return Icons.store;
    }

    // 2. Catalog String Keys (incluye las claves legadas)
    for (final BusinessIconOption option in catalog) {
      if (option.key == iconCode) return option.icon;
    }

    // 3. Legacy String Keys Mapping
    if (legacyIconsMap.containsKey(iconCode)) {
      return legacyIconsMap[iconCode]!;
    }

    // 4. Fallback
    return Icons.store;
  }

  /// Helper to get the key name for a given codePoint (used in FormScreen)
  /// Returns null if not found in catalog/legacy map.
  static String? getKeyFromCodePoint(int codePoint) {
    for (final BusinessIconOption option in catalog) {
      if (option.codePoint == codePoint) return option.key;
    }
    for (final MapEntry<String, int> entry in _legacyIconsCodePoints.entries) {
      if (entry.value == codePoint) {
        return entry.key;
      }
    }
    return null;
  }

  /// Devuelve el `codePoint` que se guarda en el modelo para una clave.
  static int? codePointOf(String key) {
    for (final BusinessIconOption option in catalog) {
      if (option.key == key) return option.codePoint;
    }
    return _legacyIconsCodePoints[key];
  }

  /// Expose the legacy map for use in Form Screen (or wherever needed)
  static Map<String, int> get legacyIcons => _legacyIconsCodePoints;
}