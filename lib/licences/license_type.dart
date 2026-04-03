/// Tipos de licencia disponibles en CashRapido
///
/// Define los diferentes niveles de suscripción que puede tener un usuario:
/// - Licencias Semanales (7 días)
/// - Licencias Mensuales (30 días)
/// - Licencias Anuales (365 días)
///
/// Cada tipo tiene 3 niveles: Personal, Pro y Enterprise
enum LicenseType {
  // Semanales (7 días)
  weeklyPersonal, // Semanal Personal - 15 CUP / $0.15 USD
  weeklyPro, // Semanal Pro - 25 CUP / $0.25 USD
  weeklyEnterprise, // Semanal Empresarial - 35 CUP / $0.35 USD
  // Mensuales (30 días)
  monthlyPersonal, // Mensual Personal - 50 CUP / $0.50 USD
  monthlyPro, // Mensual Pro - 75 CUP / $1 USD
  monthlyEnterprise, // Mensual Empresarial - 110 CUP / $1.50 USD
  // Anuales (365 días)
  annualPersonal, // Anual Personal - 500 CUP / $5 USD
  annualPro, // Anual Pro - 750 CUP / $10 USD
  annualEnterprise, // Anual Empresarial - 1000 CUP / $15 USD
  // Gratuita (sin expiración, características limitadas)
  free, // Gratuita - Sin costo
}

/// Extensión para obtener información útil sobre cada tipo de licencia
extension LicenseTypeExtension on LicenseType {
  /// Obtiene la duración en días para cada tipo de licencia
  int get durationDays {
    switch (this) {
      case LicenseType.weeklyPersonal:
      case LicenseType.weeklyPro:
      case LicenseType.weeklyEnterprise:
        return 7;
      case LicenseType.monthlyPersonal:
      case LicenseType.monthlyPro:
      case LicenseType.monthlyEnterprise:
        return 30;
      case LicenseType.annualPersonal:
      case LicenseType.annualPro:
      case LicenseType.annualEnterprise:
        return 365;
      case LicenseType.free:
        return 0; // Sin expiración
    }
  }

  /// Obtiene el nivel de la licencia (Personal, Pro, Enterprise)
  LicenseLevel get level {
    switch (this) {
      case LicenseType.weeklyPersonal:
      case LicenseType.monthlyPersonal:
      case LicenseType.annualPersonal:
        return LicenseLevel.personal;
      case LicenseType.weeklyPro:
      case LicenseType.monthlyPro:
      case LicenseType.annualPro:
        return LicenseLevel.pro;
      case LicenseType.weeklyEnterprise:
      case LicenseType.monthlyEnterprise:
      case LicenseType.annualEnterprise:
        return LicenseLevel.enterprise;
      case LicenseType.free:
        return LicenseLevel.free;
    }
  }

  /// Obtiene el período de la licencia (Weekly, Monthly, Annual)
  LicensePeriod get period {
    switch (this) {
      case LicenseType.weeklyPersonal:
      case LicenseType.weeklyPro:
      case LicenseType.weeklyEnterprise:
        return LicensePeriod.weekly;
      case LicenseType.monthlyPersonal:
      case LicenseType.monthlyPro:
      case LicenseType.monthlyEnterprise:
        return LicensePeriod.monthly;
      case LicenseType.annualPersonal:
      case LicenseType.annualPro:
      case LicenseType.annualEnterprise:
        return LicensePeriod.annual;
      case LicenseType.free:
        return LicensePeriod.lifetime;
    }
  }

  /// Verifica si es una licencia gratuita
  bool get isFree => this == LicenseType.free;

  /// Verifica si es una licencia de pago
  bool get isPaid => !isFree;

  /// Verifica si es semanal
  bool get isWeekly => period == LicensePeriod.weekly;

  /// Verifica si es mensual
  bool get isMonthly => period == LicensePeriod.monthly;

  /// Verifica si es anual
  bool get isAnnual => period == LicensePeriod.annual;
}

/// Niveles de licencia
enum LicenseLevel { free, personal, pro, enterprise }

/// Períodos de licencia
enum LicensePeriod { weekly, monthly, annual, lifetime }
