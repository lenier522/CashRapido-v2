import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

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
    // Removed check: if (!await isBalanceWidgetEnabled()) return;
    // Widgets should always update if present/requested.

    try {
      await HomeWidget.saveWidgetData<String>(
        'balance',
        balance.toStringAsFixed(2),
      );
      await HomeWidget.saveWidgetData<String>('currency', currency);
      await HomeWidget.updateWidget(androidName: 'BalanceWidgetProvider');
    } catch (e) {
      print('Error updating balance widget: $e');
    }
  }

  /// Update tips widget with a random financial tip
  static Future<void> updateTipsWidget() async {
    // Removed check: if (!await isTipsWidgetEnabled()) return;

    try {
      final random = Random();
      final randomTip = financialTips[random.nextInt(financialTips.length)];
      await HomeWidget.saveWidgetData<String>('tip', randomTip);
      await HomeWidget.updateWidget(androidName: 'TipsWidgetProvider');
    } catch (e) {
      print('Error updating tips widget: $e');
    }
  }

  /// Update all enabled widgets
  static Future<void> updateAllWidgets(double balance, String currency) async {
    await updateBalanceWidget(balance, currency);
    await updateTipsWidget();
  }
}
