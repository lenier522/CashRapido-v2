import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/localization_service.dart';

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({super.key});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final TextEditingController _nameController = TextEditingController();
  int _selectedIconCode = 0xe532; // Default restaurant
  int _selectedColorValue = 0xFFFFA726; // Default Orange

  // Curated list of colors
  final List<Color> _colors = [
    const Color(0xFFEF5350), // Red
    const Color(0xFFEC407A), // Pink
    const Color(0xFFAB47BC), // Purple
    const Color(0xFF7E57C2), // Deep Purple
    const Color(0xFF5C6BC0), // Indigo
    const Color(0xFF42A5F5), // Blue
    const Color(0xFF29B6F6), // Light Blue
    const Color(0xFF26C6DA), // Cyan
    const Color(0xFF26A69A), // Teal
    const Color(0xFF66BB6A), // Green
    const Color(0xFF9CCC65), // Light Green
    const Color(0xFFD4E157), // Lime
    const Color(0xFFFFEE58), // Yellow
    const Color(0xFFFFCA28), // Amber
    const Color(0xFFFFA726), // Orange
    const Color(0xFFFF7043), // Deep Orange
    const Color(0xFF8D6E63), // Brown
    const Color(0xFFBDBDBD), // Grey
    const Color(0xFF78909C), // Blue Grey
    const Color(0xFF000000), // Black
  ];

  // Curated list of icons (Material Icons code points)
  final List<int> _iconCodes = [
    0xe532, // restaurant
    0xe25a, // fastfood
    0xe3a0, // local_pizza
    0xe38c, // local_bar
    0xe38d, // local_cafe
    0xe1d7, // directions_car
    0xe1d5, // directions_bus
    0xe394, // local_gas_station
    0xe180, // commute
    0xe318, // home
    0xe40d, // movie
    0xe5e8, // sports_esports
    0xe39a, // local_mall
    0xe59c, // shopping_cart
    0xe59a, // shopping_bag
    0xe25b, // favorite
    0xe396, // local_hospital
    0xe28d, // fitness_center
    0xe15d, // checkroom
    0xe14d, // chair
    0xe37b, // lightbulb
    0xe559, // school
    0xe399, // local_library
    0xe4a3, // phone
    0xe11c, // business_center
    0xe3ae, // lock
    0xe31d, // home_work
    0xe116, // build
    0xe4a1, // pets
    0xe297, // flight
  ];

  void _saveCategory() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('enter_name_error'))));
      return;
    }

    Provider.of<AppProvider>(context, listen: false).addCategory(
      name: _nameController.text,
      iconCode: _selectedIconCode,
      colorValue: _selectedColorValue,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.t('new_category'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Color(_selectedColorValue),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        IconData(
                          _selectedIconCode,
                          fontFamily: 'MaterialIcons',
                        ),
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _nameController.text.isEmpty
                          ? context.t('category_name_placeholder')
                          : _nameController.text,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Name Input
              Text(
                context.t('cat_name_label'),
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  hintText: context.t('cat_name_hint'),
                  hintStyle: TextStyle(color: Theme.of(context).hintColor),
                ),
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 30),

              // Icons Grid
              Text(
                context.t('cat_icon_label'),
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  itemCount: _iconCodes.length,
                  itemBuilder: (context, index) {
                    final code = _iconCodes[index];
                    final isSelected = _selectedIconCode == code;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIconCode = code),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : (isDark ? Colors.grey[800] : Colors.grey[100]),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          IconData(code, fontFamily: 'MaterialIcons'),
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).disabledColor,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),

              // Colors Grid
              Text(
                context.t('cat_color_label'),
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  itemCount: _colors.length,
                  itemBuilder: (context, index) {
                    final color = _colors[index];
                    final isSelected = _selectedColorValue == color.toARGB32();
                    return GestureDetector(
                      onTap: () => setState(
                        () => _selectedColorValue = color.toARGB32(),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color:
                                      Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color ??
                                      Colors.black,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    context.t('save_category'),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
