import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:cashrapido/utils/number_format_utils.dart';

class WidgetService {
  static const String _balanceWidgetEnabled = 'balance_widget_enabled';
  static const String _tipsWidgetEnabled = 'tips_widget_enabled';

  // Financial tips in Spanish
  static final List<String> financialTips = [
    "Ahorra al menos el 20% de tus ingresos mensuales.",
    "Crea un fondo de emergencia equivalente a 3-6 meses de gastos.",
    "Revisa tus gastos semanalmente para identificar áreas de ahorro.",
    "Evita compras impulsivas, espera 24 horas antes de decidir.",
    "Invierte en tu educación financiera continuamente.",
    "Diversifica tus inversiones para reducir riesgos.",
    "Paga tus deudas de alto interés primero.",
    "Automatiza tus ahorros para ser más consistente.",
    "Compara precios antes de hacer compras importantes.",
    "Establece metas financieras claras y alcanzables.",
    "Reduce gastos innecesarios como suscripciones no utilizadas.",
    "Cocina en casa para ahorrar en comidas fuera.",
    "Aprovecha descuentos y ofertas de manera inteligente.",
    "Mantén un presupuesto mensual y síguelo estrictamente.",
    "Evita usar tarjetas de crédito para gastos que no puedes pagar.",
  ];

  /// Initialize widget service
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId('group.cashrapido.widgets');
  }

  /// Check if balance widget is enabled
  static Future<bool> isBalanceWidgetEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_balanceWidgetEnabled) ?? false;
  }

  /// Check if tips widget is enabled
  static Future<bool> isTipsWidgetEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tipsWidgetEnabled) ?? false;
  }

  /// Update balance widget with current main card balance
  static Future<void> updateBalanceWidget(
    double balance,
    String currency,
  ) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'balance',
        balance.toFormattedString(2),
      );
      await HomeWidget.saveWidgetData<String>('currency', currency);
      await HomeWidget.updateWidget(androidName: 'BalanceWidgetProvider');
    } catch (e) {
      print('Error updating balance widget: $e');
    }
  }

  /// Update tips widget with a random financial tip
  static Future<void> updateTipsWidget() async {
    try {
      final random = Random();
      final randomTip = financialTips[random.nextInt(financialTips.length)];
      await HomeWidget.saveWidgetData<String>('tip', randomTip);
      await HomeWidget.updateWidget(androidName: 'TipsWidgetProvider');
    } catch (e) {
      print('Error updating tips widget: $e');
    }
  }

  /// Update stats widget with income/expense data broken down by week
  ///
  /// [transactions] — list of all transactions for the current month
  /// Each transaction has an [amount] (positive = income, negative = expense)
  /// and a [date].
  static Future<void> updateStatsWidget({
    required double totalIncome,
    required double totalExpense,
    required String currency,
    // Weekly breakdown: index 0 = week 1, index 3 = week 4
    required List<double> weeklyIncome,
    required List<double> weeklyExpense,
  }) async {
    try {
      final now = DateTime.now();
      final monthLabel = _monthName(now.month);

      await HomeWidget.saveWidgetData<String>(
        'stats_income',
        totalIncome.toFormattedString(2),
      );
      await HomeWidget.saveWidgetData<String>(
        'stats_expense',
        totalExpense.toFormattedString(2),
      );
      await HomeWidget.saveWidgetData<String>('stats_month', monthLabel);

      // Save weekly bars (up to 4 weeks)
      for (int i = 0; i < 4; i++) {
        final income = i < weeklyIncome.length ? weeklyIncome[i] : 0.0;
        final expense = i < weeklyExpense.length ? weeklyExpense[i] : 0.0;
        await HomeWidget.saveWidgetData<String>('stats_w${i + 1}_income', income.toStringAsFixed(2));
        await HomeWidget.saveWidgetData<String>('stats_w${i + 1}_expense', expense.toStringAsFixed(2));
      }

      await HomeWidget.updateWidget(androidName: 'StatsWidgetProvider');
    } catch (e) {
      print('Error updating stats widget: $e');
    }
  }

  static String _monthName(int month) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  /// Update all widgets
  static Future<void> updateAllWidgets(double balance, String currency) async {
    await updateBalanceWidget(balance, currency);
    await updateTipsWidget();
  }

  /// Compute weekly income/expense from a month's transactions and update stats widget.
  /// Transactions must be of the current month. [amount] positive = income, negative = expense.
  static Future<void> computeAndUpdateStatsWidget({
    required List<({double amount, DateTime date})> transactions,
    required String currency,
  }) async {
    final weeklyIncome = [0.0, 0.0, 0.0, 0.0];
    final weeklyExpense = [0.0, 0.0, 0.0, 0.0];
    double totalIncome = 0.0;
    double totalExpense = 0.0;

    for (final tx in transactions) {
      // Determine week index (0-3) based on day of month
      final day = tx.date.day;
      final weekIdx = ((day - 1) / 7).floor().clamp(0, 3);

      if (tx.amount > 0) {
        weeklyIncome[weekIdx] += tx.amount;
        totalIncome += tx.amount;
      } else {
        weeklyExpense[weekIdx] += tx.amount.abs();
        totalExpense += tx.amount.abs();
      }
    }

    await updateStatsWidget(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      currency: currency,
      weeklyIncome: weeklyIncome,
      weeklyExpense: weeklyExpense,
    );
  }

  /// Update streak widget with daily streak and weekly progress (Duolingo style)
  static Future<void> updateStreakWidget({
    required int streakDays,
    required List<String> loginDates,
  }) async {
    try {
      final now = DateTime.now();
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final isTodayDone = loginDates.contains(todayStr);

      // Current week: Monday (1) to Sunday (7)
      final monday = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      final weekFlags = <String>[];
      for (int i = 0; i < 7; i++) {
        final d = monday.add(Duration(days: i));
        final dStr =
            "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
        weekFlags.add(loginDates.contains(dStr) ? "1" : "0");
      }

      final todayIndex = (now.weekday - 1).clamp(0, 6);
      final targetProgress = streakDays % 50;

      final subtitle = isTodayDone
          ? "¡Racha activa hoy!"
          : "¡Entra hoy para no perderla!";
      final motivation = isTodayDone
          ? "🔥 ¡Excelente constancia! Racha protegida por hoy."
          : "⚡ ¡No dejes apagar la llama! Entra a la app hoy.";

      await HomeWidget.saveWidgetData<String>('streak_count', streakDays.toString());
      await HomeWidget.saveWidgetData<String>('streak_subtitle', subtitle);
      await HomeWidget.saveWidgetData<String>('streak_target', "🎁 $targetProgress/50");
      await HomeWidget.saveWidgetData<String>('streak_motivation', motivation);
      await HomeWidget.saveWidgetData<String>('streak_week', weekFlags.join(","));
      await HomeWidget.saveWidgetData<String>('streak_today_index', todayIndex.toString());

      await HomeWidget.updateWidget(androidName: 'StreakWidgetProvider');
    } catch (e) {
      // Silently ignore widget errors to prevent any app crashes
    }
  }
}
