import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/localization_service.dart';

enum TimeRange { day, week, month, year, custom }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _touchedIndex = -1;
  DateTime _selectedDate = DateTime.now();
  bool _showIncome = false;
  TimeRange _timeRange = TimeRange.month;
  String _accountTypeFilter = 'all'; // 'all', 'card', 'cash'
  DateTimeRange? _customDateRange;

  void _updateDate(int direction) {
    setState(() {
      switch (_timeRange) {
        case TimeRange.day:
          _selectedDate = _selectedDate.add(Duration(days: direction));
          break;
        case TimeRange.week:
          _selectedDate = _selectedDate.add(Duration(days: direction * 7));
          break;
        case TimeRange.month:
          _selectedDate = DateTime(
            _selectedDate.year,
            _selectedDate.month + direction,
            _selectedDate.day,
          );
          break;
        case TimeRange.year:
          _selectedDate = DateTime(
            _selectedDate.year + direction,
            _selectedDate.month,
            _selectedDate.day,
          );
          break;
        case TimeRange.custom:
          // Do nothing for custom range navigation for now
          break;
      }
    });
  }

  String _getDateLabel(BuildContext context) {
    final dateFormat = DateFormat.yMMMMd(
      Localizations.localeOf(context).toString(),
    );
    final monthFormat = DateFormat.yMMMM(
      Localizations.localeOf(context).toString(),
    );
    final yearFormat = DateFormat.y(Localizations.localeOf(context).toString());

    switch (_timeRange) {
      case TimeRange.day:
        return dateFormat.format(_selectedDate);
      case TimeRange.week:
        final startOfWeek = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '${DateFormat.MMMd().format(startOfWeek)} - ${DateFormat.MMMd().format(endOfWeek)}';
      case TimeRange.month:
        return monthFormat.format(_selectedDate);
      case TimeRange.year:
        return yearFormat.format(_selectedDate);
      case TimeRange.custom:
        if (_customDateRange == null) return context.t('select_date');
        return '${DateFormat.MMMd().format(_customDateRange!.start)} - ${DateFormat.MMMd().format(_customDateRange!.end)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.t('statistics'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        actions: [
          IconButton(
            onPressed: () => _showDatePickerForRange(context),
            icon: Icon(
              Icons.calendar_month_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          final transactions = provider.transactions;
          final categories = provider.categories;

          // Filter Logic
          final filteredTransactions = transactions
              .where((t) {
                final date = t.date;
                switch (_timeRange) {
                  case TimeRange.day:
                    return date.year == _selectedDate.year &&
                        date.month == _selectedDate.month &&
                        date.day == _selectedDate.day;
                  case TimeRange.week:
                    final startOfWeek = _selectedDate.subtract(
                      Duration(days: _selectedDate.weekday - 1),
                    );
                    final endOfWeek = startOfWeek.add(const Duration(days: 6));
                    final tDate = DateTime(date.year, date.month, date.day);
                    final sDate = DateTime(
                      startOfWeek.year,
                      startOfWeek.month,
                      startOfWeek.day,
                    );
                    final eDate = DateTime(
                      endOfWeek.year,
                      endOfWeek.month,
                      endOfWeek.day,
                    );
                    return tDate.isAfter(
                          sDate.subtract(const Duration(seconds: 1)),
                        ) &&
                        tDate.isBefore(eDate.add(const Duration(seconds: 1)));
                  case TimeRange.month:
                    return date.month == _selectedDate.month &&
                        date.year == _selectedDate.year;
                  case TimeRange.year:
                    return date.year == _selectedDate.year;
                  case TimeRange.custom:
                    if (_customDateRange == null) return false;
                    final start = _customDateRange!.start;
                    final end = _customDateRange!.end;
                    final tDate = DateTime(date.year, date.month, date.day);
                    final sDate = DateTime(start.year, start.month, start.day);
                    final eDate = DateTime(end.year, end.month, end.day);
                    return !tDate.isBefore(sDate) && !tDate.isAfter(eDate);
                }
              })
              .where((t) {
                if (_accountTypeFilter == 'all') return true;

                // We need to check the card associated with the transaction (t.cardId)
                // However, Transaction model might not hold full card info, just ID.
                // We need to look up the card in provider.cards
                if (t.cardId == null)
                  return false; // Or handle as generic expense? usually mapped

                try {
                  final card = provider.cards.firstWhere(
                    (c) => c.id == t.cardId,
                  );
                  if (_accountTypeFilter == 'cash') return card.isCash;
                  if (_accountTypeFilter == 'card') return !card.isCash;
                } catch (e) {
                  return false; // Card deleted or not found
                }
                return true;
              })
              .toList();

          // Calculate Totals
          final Map<String, double> categoryTotals = {};
          double totalExpense = 0;

          for (var tx in filteredTransactions) {
            final isExpense = tx.amount < 0;
            final isIncome = tx.amount > 0;
            if ((_showIncome && isIncome) || (!_showIncome && isExpense)) {
              final amount = tx.amount.abs();
              categoryTotals[tx.categoryId] =
                  (categoryTotals[tx.categoryId] ?? 0) + amount;
              totalExpense += amount;
            }
          }

          // Chart Widget
          Widget chartWidget;
          if (totalExpense == 0) {
            chartWidget = Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bar_chart_rounded,
                      size: 40,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${context.t('no_data')} ${_getDateLabel(context)}',
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).disabledColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          } else if (provider.chartType == 'Bar') {
            chartWidget = _buildBarChart(categoryTotals, categories);
          } else if (provider.chartType == 'Line') {
            chartWidget = _buildLineChart(filteredTransactions);
          } else {
            chartWidget = _buildPieChart(
              categoryTotals,
              categories,
              totalExpense,
            );
          }

          // List Items
          final List<Widget> categoryListItems = [];
          if (totalExpense > 0) {
            final sortedEntries = categoryTotals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            for (var entry in sortedEntries) {
              final category = _getCategory(context, categories, entry.key);
              final percentage = (entry.value / totalExpense) * 100;
              categoryListItems.add(
                _buildCategoryItem(
                  category.name,
                  '${_showIncome ? '+' : '-'}\$${entry.value.toStringAsFixed(2)}',
                  '${percentage.toStringAsFixed(1)}%',
                  Color(category.colorValue),
                  IconData(category.iconCode, fontFamily: 'MaterialIcons'),
                ),
              );
            }
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Modern Tab Selector
                _buildModernTabSelector(context),
                const SizedBox(height: 16),

                // Account Type Filter
                _buildAccountTypeFilter(context),
                const SizedBox(height: 20),

                // Date Navigator
                _buildDateNavigator(context),
                const SizedBox(height: 10),

                // Chart Container
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getDynamicTitle(_showIncome),
                                  style: GoogleFonts.outfit(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withOpacity(0.7),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${totalExpense.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Income/Expense Toggle Switch
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                _buildToggleOption(
                                  context,
                                  false,
                                  Icons.arrow_downward_rounded,
                                  !_showIncome,
                                ),
                                _buildToggleOption(
                                  context,
                                  true,
                                  Icons.arrow_upward_rounded,
                                  _showIncome,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(height: 220, child: chartWidget),
                      const SizedBox(height: 16),
                      // Chart Type Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildChartTypeButton(
                            context,
                            'Pie',
                            Icons.pie_chart_rounded,
                            provider,
                          ),
                          const SizedBox(width: 8),
                          _buildChartTypeButton(
                            context,
                            'Bar',
                            Icons.bar_chart_rounded,
                            provider,
                          ),
                          const SizedBox(width: 8),
                          _buildChartTypeButton(
                            context,
                            'Line',
                            Icons.show_chart_rounded,
                            provider,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Category List Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        context.t(
                          'category_label',
                        ), // Using existing key for 'Category'
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // List Items
                if (categoryListItems.isEmpty && totalExpense == 0)
                  Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Text(
                      context.t('no_data'),
                      style: GoogleFonts.outfit(
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                  )
                else
                  ...categoryListItems,

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  // -- Helper Widgets --

  Widget _buildModernTabSelector(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: TimeRange.values.map((range) {
          final isSelected = _timeRange == range;
          String label = '';
          switch (range) {
            case TimeRange.day:
              label = context.t('day');
              break;
            case TimeRange.week:
              label = context.t('week');
              break;
            case TimeRange.month:
              label = context.t('month');
              break;
            case TimeRange.year:
              label = context.t('year');
              break;
            case TimeRange.custom:
              label = context.t('range');
              break;
          }

          return GestureDetector(
            onTap: () async {
              if (range == TimeRange.custom) {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDateRange:
                      _customDateRange ??
                      DateTimeRange(
                        start: DateTime.now().subtract(const Duration(days: 7)),
                        end: DateTime.now(),
                      ),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.dark(
                          primary: Theme.of(context).colorScheme.primary,
                          onPrimary: Colors.white,
                          surface: Theme.of(context).cardColor,
                          onSurface: Theme.of(
                            context,
                          ).textTheme.bodyLarge!.color!,
                        ),
                        dialogTheme: DialogThemeData(
                          backgroundColor: Theme.of(
                            context,
                          ).scaffoldBackgroundColor,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() {
                    _timeRange = TimeRange.custom;
                    _customDateRange = picked;
                  });
                }
                return;
              }
              setState(() => _timeRange = range);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : Theme.of(context).dividerColor.withOpacity(0.1),
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateNavigator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            onPressed: () => setState(() => _updateDate(-1)),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).cardColor,
              padding: const EdgeInsets.all(12),
            ),
          ),
          Text(
            _getDateLabel(context),
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 20,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            onPressed: () => setState(() => _updateDate(1)),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).cardColor,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption(
    BuildContext context,
    bool isIncome,
    IconData icon,
    bool isActive,
  ) {
    return GestureDetector(
      onTap: () => setState(() => _showIncome = isIncome),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).disabledColor,
        ),
      ),
    );
  }

  Widget _buildChartTypeButton(
    BuildContext context,
    String type,
    IconData icon,
    AppProvider provider,
  ) {
    final isSelected = provider.chartType == type;
    return GestureDetector(
      onTap: () => provider.setChartType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Theme.of(context).disabledColor,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildCategoryItem(
    String title,
    String amount,
    String percentage,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  percentage,
                  style: GoogleFonts.outfit(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Category _getCategory(
    BuildContext context,
    List<Category> categories,
    String catId,
  ) {
    // Check for ID match first
    try {
      final category = categories.firstWhere((c) => c.id == catId);
      // Translate if it's a default category
      if (category.id.startsWith('cat_')) {
        return Category(
          id: category.id,
          name: context.t(category.id),
          iconCode: category.iconCode,
          colorValue: category.colorValue,
          isCustom: category.isCustom,
        );
      }
      return category;
    } catch (e) {
      // Fallback for system categories
      if (catId == 'transfer_out' || catId == 'transfer_in') {
        return Category(
          id: 'transfers',
          name: context.t('cat_transfer'),
          iconCode: 0xe044, // swap_horiz
          colorValue: 0xFF9E9E9E,
          isCustom: false,
        );
      }
      if (catId == 'recharge') {
        return Category(
          id: 'recharge',
          name: context.t('cat_recharge'),
          iconCode: 0xe636, // credit_card
          colorValue: 0xFF2196F3,
          isCustom: false,
        );
      }
      if (catId == 'income_request') {
        return Category(
          id: 'income_request',
          name: context.t('cat_request'),
          iconCode: 0xf1c6, // request_quote
          colorValue: 0xFF4CAF50,
          isCustom: false,
        );
      }
      if (catId == 'general') {
        return Category(
          id: 'general',
          name: context.t('cat_general'),
          iconCode: 0xe88e, // info
          colorValue: 0xFF607D8B,
          isCustom: false,
        );
      }
      return Category(
        id: 'unknown',
        name: context.t('cat_unknown'),
        iconCode: 0xe8fd,
        colorValue: 0xFF9E9E9E,
        isCustom: false,
      );
    }
  }

  // --- Chart Builders ---

  Widget _buildPieChart(
    Map<String, double> categoryTotals,
    List<Category> categories,
    double totalExpense,
  ) {
    final showingSections = <PieChartSectionData>[];
    int index = 0;

    categoryTotals.forEach((catId, amount) {
      final category = _getCategory(context, categories, catId);
      final percentage = (amount / totalExpense) * 100;
      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 60.0 : 50.0;
      final fontSize = isTouched ? 20.0 : 14.0;

      showingSections.add(
        PieChartSectionData(
          color: Color(category.colorValue),
          value: percentage,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: radius,
          titleStyle: GoogleFonts.outfit(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      index++;
    });

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  pieTouchResponse == null ||
                  pieTouchResponse.touchedSection == null) {
                _touchedIndex = -1;
                return;
              }
              _touchedIndex =
                  pieTouchResponse.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 0,
        centerSpaceRadius: 40,
        sections: showingSections,
      ),
    );
  }

  Widget _buildBarChart(
    Map<String, double> categoryTotals,
    List<Category> categories,
  ) {
    // Sort logic here or passed in. Let's pick top 5.
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(5).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (topEntries.isNotEmpty ? topEntries.first.value : 100) * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.blueGrey,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final catName = _getCategory(
                  context,
                  categories,
                  topEntries[group.x.toInt()].key,
                ).name;
                return BarTooltipItem(
                  '$catName\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: (rod.toY).toStringAsFixed(0),
                      style: const TextStyle(color: Colors.yellow),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value.toInt() >= topEntries.length) {
                    return const SizedBox();
                  }
                  final cat = _getCategory(
                    context,
                    categories,
                    topEntries[value.toInt()].key,
                  );
                  return SideTitleWidget(
                    meta: meta,
                    child: Icon(
                      IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                      color: Theme.of(
                        context,
                      ).iconTheme.color?.withOpacity(0.7),
                      size: 20,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: topEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final cat = _getCategory(context, categories, data.key);

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: data.value,
                  color: Color(cat.colorValue),
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY:
                        (topEntries.isNotEmpty ? topEntries.first.value : 100) *
                        1.2,
                    color: Theme.of(context).cardColor,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLineChart(List<InternalTransaction> transactions) {
    // Sort transactions by date first to ensure correct plotting
    final sortedTxs = List<InternalTransaction>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Group expenses by Day (1..31) or valid range
    // Since we can be in Day/Week/Month/Year view, we should adapt the X axis.
    // For simplicity in this "Line" view which is often Month-based:
    // We will map Day -> Total Amount.

    final Map<int, double> dailyExpenses = {};
    // Determine max days based on month
    final daysInMonth = DateUtils.getDaysInMonth(
      _selectedDate.year,
      _selectedDate.month,
    );

    for (var i = 1; i <= daysInMonth; i++) {
      dailyExpenses[i] = 0.0;
    }

    for (var tx in sortedTxs) {
      // Only count if it matches the selected filtering scope (which relies on filteredTransactions passed in)
      // Check if logic for matching day/month is consistent
      // Assuming filteredTransactions passed in are already filtered by Date Logic
      if (tx.amount < 0) {
        dailyExpenses[tx.date.day] =
            (dailyExpenses[tx.date.day] ?? 0) + tx.amount.abs();
      }
    }

    final spots = dailyExpenses.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    final maxY = spots.isEmpty
        ? 100.0
        : spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 1,
          maxX: daysInMonth.toDouble(),
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDatePickerForRange(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).cardColor,
              onSurface: Theme.of(context).textTheme.bodyLarge!.color!,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        // If range was custom, maybe switch to Day or Month?
        // User didn't specify, but picking a date usually implies jumping to that day/month context.
        // Let's keep current range type but update anchor date.
      });
    }
  }

  Widget _buildAccountTypeFilter(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTypeFilterOption(context, 'all', context.t('all_accounts')),
            _buildTypeFilterOption(
              context,
              'card',
              context.t('bank_cards_only'),
            ),
            _buildTypeFilterOption(context, 'cash', context.t('cash_only')),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeFilterOption(
    BuildContext context,
    String value,
    String label,
  ) {
    final isSelected = _accountTypeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _accountTypeFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected
                ? Colors.white
                : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  String _getDynamicTitle(bool isIncome) {
    String typeIdx = isIncome ? 'income' : 'expense';
    String rangeLabel = '';

    switch (_timeRange) {
      case TimeRange.day:
        rangeLabel = context.t('day');
        break;
      case TimeRange.week:
        rangeLabel = context.t('week');
        break;
      case TimeRange.month:
        rangeLabel = context.t('month');
        break;
      case TimeRange.year:
        rangeLabel = context.t('year');
        break;
      case TimeRange.custom:
        rangeLabel = context.t('range');
        break;
    }

    return "${context.t(typeIdx)} ($rangeLabel)";
  }
}
