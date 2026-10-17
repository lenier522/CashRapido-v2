import '../models/models.dart';

/// Agregaciones de estadísticas de CashRapido.
///
/// Todas las funciones de este archivo son **puras**: reciben movimientos ya
/// consultados y devuelven resultados, sin tocar Hive, sin red y sin estado
/// global. Así se centraliza en un único sitio la regla financiera que usan
/// Analítica, Proyección y Calendario, en lugar de repetirla en cada widget.
///
/// ## Regla de clasificación
///
/// Se conserva exactamente la que venía usando `stats_screen`:
///
/// - ingreso: `amount > 0`
/// - gasto: `amount < 0`
/// - `amount == 0` no se cuenta en ninguno de los dos
///
/// Las transferencias entre tarjetas se guardan como dos movimientos reales
/// (`transfer_out` con importe negativo y `transfer_in` con importe positivo)
/// con id propio. Esta regla las clasifica **por su signo**, igual que antes,
/// de modo que no cambian resultados financieros ya mostrados al usuario.
class StatsAggregator {
  const StatsAggregator._();

  /// Día natural (sin hora ni minutos) usando la zona horaria local.
  static DateTime dayOf(DateTime date) => DateTime(
    date.year,
    date.month,
    date.day,
  );

  /// Primer y último día natural de un mes.
  static DateTime firstDayOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static DateTime lastDayOfMonth(DateTime date) => DateTime(
    date.year,
    date.month + 1,
    1,
  ).subtract(const Duration(days: 1));

  /// Días naturales que tiene un mes (28, 29, 30 o 31).
  static int daysInMonth(DateTime date) =>
      lastDayOfMonth(date).day;

  /// Clave única de un día natural para agrupar sin depender de la hora.
  static int _dayKey(DateTime day) => day.day + day.month * 100 + day.year * 100000;

  /// Suma ingresos y gastos de un conjunto de movimientos.
  ///
  /// Sin [side] devuelve **ambos lados** siempre, que es lo necesario para el
  /// balance del período y la tasa de ahorro. Con [side] se limita a una sola
  /// cara, que es lo que necesitan las gráficas y el desglose por categorías;
  /// en ese caso `count` sigue contando todos los registros recibidos, igual
  /// que hacía el resumen anterior.
  static StatsTotals totals(
    Iterable<InternalTransaction> transactions, {
    StatsSide? side,
  }) {
    double income = 0;
    double expense = 0;
    int count = 0;
    final Map<String, double> byCategory = <String, double>{};

    for (final InternalTransaction transaction in transactions) {
      count++;
      final double amount = transaction.amount;
      // Los movimientos de importe cero no son ingreso ni gasto: se cuentan
      // en el total de registros pero no en ningún total monetario.
      if (amount == 0) continue;
      final bool isIncome = amount > 0;
      if (side == StatsSide.income && !isIncome) continue;
      if (side == StatsSide.expense && isIncome) continue;

      final double value = amount.abs();
      if (isIncome) {
        income += value;
      } else {
        expense += value;
      }
      byCategory[transaction.categoryId] =
          (byCategory[transaction.categoryId] ?? 0) + value;
    }

    return StatsTotals(
      income: income,
      expense: expense,
      count: count,
      byCategory: byCategory,
    );
  }

  /// Totales agrupados por día natural dentro de un rango.
  ///
  /// Devuelve **todos** los días del rango, incluidos los que no tienen
  /// movimientos (con ceros). Un día sin registros significa que no hubo
  /// actividad, no que falte información: así el calendario y las gráficas
  /// diarias pueden distinguir "no pasó nada" de "no hay datos".
  static List<DayTotals> dailyTotals(
    Iterable<InternalTransaction> transactions, {
    required DateTime start,
    required DateTime end,
  }) {
    final DateTime firstDay = dayOf(start);
    final DateTime lastDay = dayOf(end);
    if (lastDay.isBefore(firstDay)) return const <DayTotals>[];

    final Map<int, _Accumulator> byDay = <int, _Accumulator>{};
    for (final InternalTransaction transaction in transactions) {
      final DateTime day = dayOf(transaction.date);
      if (day.isBefore(firstDay) || day.isAfter(lastDay)) continue;
      final _Accumulator accumulator = byDay.putIfAbsent(
        _dayKey(day),
        () => _Accumulator(day),
      );
      final double amount = transaction.amount;
      if (amount > 0) {
        accumulator.income += amount;
      } else if (amount < 0) {
        accumulator.expense += -amount;
      }
      accumulator.count++;
    }

    final List<DayTotals> result = <DayTotals>[];
    DateTime cursor = firstDay;
    while (!cursor.isAfter(lastDay)) {
      final _Accumulator? accumulator = byDay[_dayKey(cursor)];
      result.add(
        DayTotals(
          day: cursor,
          income: accumulator?.income ?? 0,
          expense: accumulator?.expense ?? 0,
          count: accumulator?.count ?? 0,
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }

  /// Tasa de ahorro: porcentaje de los ingresos que queda tras los gastos.
  ///
  ///     (ingresos - gastos) / ingresos * 100
  ///
  /// Devuelve `null` cuando no hay ingresos, porque en ese caso la división no
  /// tiene significado y mostrar un porcentaje sería engañoso. **No se recorta
  /// al intervalo 0–100**: si los gastos superan a los ingresos la tasa es
  /// negativa y eso refleja los datos reales, no un fallo de cálculo.
  static double? savingsRate({
    required double income,
    required double expense,
  }) {
    if (income <= 0) return null;
    return (income - expense) / income * 100;
  }

  /// Estimación de cómo cerraría el mes natural si se mantiene el ritmo
  /// observado hasta ahora.
  ///
  /// Método: proyección lineal sobre **días naturales**.
  ///
  ///     ingresos proyectados  = ingresos acumulados / días transcurridos
  ///                             * días del mes
  ///     gastos proyectados    = gastos acumulados   / días transcurridos
  ///                             * días del mes
  ///     balance proyectado    = ingresos proyectados - gastos proyectados
  ///
  /// El día actual se incluye en los días transcurridos, así que con un solo
  /// día de datos el denominador es 1. Nunca se usan días de actividad
  /// financiera como denominador: el método es estrictamente natural.
  ///
  /// La proyección es una **estimación**, nunca un resultado real, y por eso
  /// se expresa en un tipo propio para poder etiquetarla como tal en la
  /// interfaz. No escribe ni modifica ningún registro.
  static MonthlyProjection projection({
    required DateTime today,
    required DateTime month,
    required StatsTotals accumulated,
  }) {
    final DateTime start = firstDayOfMonth(month);
    final DateTime end = lastDayOfMonth(month);
    final int totalDays = daysInMonth(month);
    // El día de hoy cuenta como transcurrido: es el día que se está viviendo.
    final int elapsedDays = today.isBefore(start)
        ? 0
        : today.isAfter(end)
        ? totalDays
        : today.day;

    final bool isCurrentMonth = today.year == month.year &&
        today.month == month.month;
    // Sin días transcurridos no hay ritmo observado del que proyectar.
    final bool canProject =
        isCurrentMonth && elapsedDays > 0 && elapsedDays < totalDays;

    final bool hasIncomeData = accumulated.income > 0;
    final bool hasExpenseData = accumulated.expense > 0;

    // Sin ingresos registrados no se afirma cómo cerrarán los ingresos: se
    // marca la estimación como no disponible en lugar de inventar un valor.
    final bool incomeProjectionReliable = canProject && hasIncomeData;
    final bool expenseProjectionReliable = canProject && hasExpenseData;

    final double factor = canProject ? totalDays / elapsedDays : 0;
    final double projectedIncome = incomeProjectionReliable
        ? accumulated.income * factor
        : 0;
    final double projectedExpense = expenseProjectionReliable
        ? accumulated.expense * factor
        : 0;

    return MonthlyProjection(
      start: start,
      end: end,
      totalDays: totalDays,
      elapsedDays: elapsedDays,
      accumulatedIncome: accumulated.income,
      accumulatedExpense: accumulated.expense,
      accumulatedCount: accumulated.count,
      projectedIncome: projectedIncome,
      projectedExpense: projectedExpense,
      isCurrentMonth: isCurrentMonth,
      canProject: canProject,
      incomeProjectionReliable: incomeProjectionReliable,
      expenseProjectionReliable: expenseProjectionReliable,
    );
  }
}

/// Acumulador temporal usado para agrupar por día.
class _Accumulator {
  _Accumulator(this.day);
  final DateTime day;
  double income = 0;
  double expense = 0;
  int count = 0;
}

/// Ingresos, gastos y registros de un conjunto de movimientos.
class StatsTotals {
  final double income;
  final double expense;
  final int count;

  /// Suma de importes absolutos por categoría, para desgloses.
  final Map<String, double> byCategory;

  const StatsTotals({
    required this.income,
    required this.expense,
    required this.count,
    required this.byCategory,
  });

  /// Balance del período: ingresos menos gastos.
  ///
  /// No es el saldo disponible de una cuenta ni el total de la billetera.
  double get net => income - expense;

  /// `true` si no hay ningún movimiento registrado.
  bool get isEmpty => count == 0;

  /// Tasa de ahorro del período, o `null` si no hay ingresos.
  double? get savingsRate =>
      StatsAggregator.savingsRate(income: income, expense: expense);
}

/// Totales de un día natural concreto.
class DayTotals {
  final DateTime day;
  final double income;
  final double expense;
  final int count;

  const DayTotals({
    required this.day,
    required this.income,
    required this.expense,
    required this.count,
  });

  double get net => income - expense;

  /// `true` si el día no tiene ningún movimiento.
  bool get isEmpty => count == 0;

  bool get hasIncome => income > 0;
  bool get hasExpense => expense > 0;

  /// Cómo termina el día para poder distinguirlo en el calendario sin depender
  /// únicamente del color.
  DayActivity get activity {
    if (hasIncome && hasExpense) return DayActivity.both;
    if (hasIncome) return DayActivity.income;
    if (hasExpense) return DayActivity.expense;
    return DayActivity.none;
  }
}

/// Tipo de actividad de un día del calendario.
enum DayActivity { none, income, expense, both }

/// Cara de un movimiento para las consultas de una sola cara.
enum StatsSide { income, expense }

/// Estimación de cierre de un mes natural.
class MonthlyProjection {
  final DateTime start;
  final DateTime end;
  final int totalDays;
  final int elapsedDays;

  /// Resultados **reales** acumulados hasta el momento.
  final double accumulatedIncome;
  final double accumulatedExpense;
  final int accumulatedCount;

  /// Valores **estimados** al cierre del mes.
  final double projectedIncome;
  final double projectedExpense;

  /// `true` si el mes consultado es el que está en curso.
  final bool isCurrentMonth;

  /// `true` si hay días transcurridos y el mes aún no terminó.
  final bool canProject;

  /// `false` cuando no hay ingresos registrados y, por tanto, no procede
  /// afirmar cómo cerrarán los ingresos.
  final bool incomeProjectionReliable;
  final bool expenseProjectionReliable;

  const MonthlyProjection({
    required this.start,
    required this.end,
    required this.totalDays,
    required this.elapsedDays,
    required this.accumulatedIncome,
    required this.accumulatedExpense,
    required this.accumulatedCount,
    required this.projectedIncome,
    required this.projectedExpense,
    required this.isCurrentMonth,
    required this.canProject,
    required this.incomeProjectionReliable,
    required this.expenseProjectionReliable,
  });

  /// Balance **real** acumulado.
  double get accumulatedNet => accumulatedIncome - accumulatedExpense;

  /// Balance **estimado** al cierre del mes.
  double? get projectedNet =>
      incomeProjectionReliable && expenseProjectionReliable
      ? projectedIncome - projectedExpense
      : null;

  /// Parte del período que ya se ha vivido, en tanto por uno (0–1).
  ///
  /// `null` si no hay base para calcularla.
  double? get progress => totalDays > 0 ? elapsedDays / totalDays : null;

  /// `true` cuando no hay nada que mostrar (mes sin movimientos).
  bool get isEmpty => accumulatedCount == 0;

  /// `true` si el mes ya está completo: la estimación coincide con lo real.
  bool get isMonthComplete => elapsedDays >= totalDays;
}
