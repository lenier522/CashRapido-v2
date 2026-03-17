import 'package:flutter/material.dart';

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

  /// Parses iconCode which can be an integer string (codePoint) or a legacy string key (e.g. 'restaurant')
  /// Returns the correct IconData, defaulting to Icons.store if invalid.
  static IconData getIcon(String iconCode) {
    // 1. Try to parse as integer (New Format: codePoint)
    final codePoint = int.tryParse(iconCode);
    if (codePoint != null) {
      if (_codePointToIcon.containsKey(codePoint)) {
        return _codePointToIcon[codePoint]!;
      }
      return Icons.store;
    }

    // 2. Legacy String Keys Mapping
    if (legacyIconsMap.containsKey(iconCode)) {
      return legacyIconsMap[iconCode]!;
    }

    // 3. Fallback
    return Icons.store;
  }

  /// Helper to get the key name for a given codePoint (used in FormScreen)
  /// Returns null if not found in legacy map
  static String? getKeyFromCodePoint(int codePoint) {
    for (var entry in _legacyIconsCodePoints.entries) {
      if (entry.value == codePoint) {
        return entry.key;
      }
    }
    return null;
  }

  /// Expose the map for use in Form Screen (or wherever needed)
  static Map<String, int> get legacyIcons => _legacyIconsCodePoints;
}
