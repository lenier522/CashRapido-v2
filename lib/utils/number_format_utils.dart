import '../providers/app_provider.dart';

extension NumberFormatting on num {
  String toFormattedString([int fractionDigits = 2]) {
    String formatted = toStringAsFixed(fractionDigits);
    if (AppProvider.decimalSeparator == ',') {
      formatted = formatted.replaceAll('.', ',');
    }
    return formatted;
  }
}
