import 'package:flutter/material.dart';

class IconConstants {
  static const Map<int, IconData> categoryIconMap = {
    0xe532: Icons.restaurant,
    0xe25a: Icons.fastfood,
    0xe3a0: Icons.local_pizza,
    0xe38c: Icons.local_bar,
    0xe38d: Icons.local_cafe,
    0xe1d7: Icons.directions_car,
    0xe1d5: Icons.directions_bus,
    0xe394: Icons.local_gas_station,
    0xe180: Icons.commute,
    0xe318: Icons.home,
    0xe40d: Icons.movie,
    0xe5e8: Icons.sports_esports,
    0xe39a: Icons.local_mall,
    0xe59c: Icons.shopping_cart,
    0xe59a: Icons.shopping_bag,
    0xe25b: Icons.favorite,
    0xe396: Icons.local_hospital,
    0xe28d: Icons.fitness_center,
    0xe15d: Icons.checkroom,
    0xe14d: Icons.chair,
    0xe37b: Icons.lightbulb,
    0xe559: Icons.school,
    0xe399: Icons.local_library,
    0xe4a3: Icons.phone,
    0xe11c: Icons.business_center,
    0xe3ae: Icons.lock,
    0xe31d: Icons.home_work,
    0xe116: Icons.build,
    0xe4a1: Icons.pets,
    0xe297: Icons.flight,
    0xe8fd: Icons.help_outline,
  };

  static IconData getCategoryIcon(int codePoint) {
    if (categoryIconMap.containsKey(codePoint)) {
      return categoryIconMap[codePoint]!;
    }
    return Icons.help_outline; // Default fallback wrapper
  }
}
