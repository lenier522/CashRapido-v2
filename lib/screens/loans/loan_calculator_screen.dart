import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  double _principal = 1000.0;
  double _interestRate = 10.0;
  int _duration = 10;
  
  String _interestType = 'simple'; // 'fixed', 'simple', 'compound'
  String _frequency = 'weekly'; // 'daily', 'weekly', 'biweekly', 'monthly'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculations
    final totalRepayment = _calculateTotalRepayment();
    final totalProfit = totalRepayment - _principal;
    final installmentAmount = totalRepayment / _duration;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          Localizations.localeOf(context).languageCode == 'es' ? 'Simulador de Préstamos' : 'Repayment Simulator',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dashboard Metrics simulated panel
            _buildSimulationResults(totalRepayment, totalProfit, installmentAmount, isDark),
            const SizedBox(height: 28),

            Text(
              Localizations.localeOf(context).languageCode == 'es' ? 'Parámetros del Préstamo' : 'Simulating Parameters',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Principal
            _buildSliderSection(
              title: Localizations.localeOf(context).languageCode == 'es' ? 'Monto Solicitado (Capital)' : 'Principal Capital',
              value: _principal,
              min: 100,
              max: 20000,
              divisions: 199,
              displayVal: "\$${_principal.toStringAsFixed(0)}",
              onChanged: (val) {
                setState(() {
                  _principal = val;
                });
              },
              isDark: isDark,
            ),
            const SizedBox(height: 20),

            // Interest type
            _buildInterestTypeSelector(isDark),
            const SizedBox(height: 20),

            // Interest Rate
            _buildSliderSection(
              title: _interestType == 'fixed'
                  ? (Localizations.localeOf(context).languageCode == 'es' ? 'Monto de Interés Fijo' : 'Fixed Interest Payout')
                  : (Localizations.localeOf(context).languageCode == 'es' ? 'Tasa de Interés (%)' : 'Interest Rate (%)'),
              value: _interestRate,
              min: 1,
              max: _interestType == 'fixed' ? 5000 : 100,
              divisions: _interestType == 'fixed' ? 100 : 99,
              displayVal: _interestType == 'fixed' 
                  ? "\$${_interestRate.toStringAsFixed(0)}" 
                  : "${_interestRate.toStringAsFixed(0)}%",
              onChanged: (val) {
                setState(() {
                  _interestRate = val;
                });
              },
              isDark: isDark,
            ),
            const SizedBox(height: 20),

            // Frequency
            _buildFrequencySelector(isDark),
            const SizedBox(height: 20),

            // Duration
            _buildSliderSection(
              title: Localizations.localeOf(context).languageCode == 'es' ? 'Plazo de Amortización (Cuotas)' : 'Amortization Term (Installments)',
              value: _duration.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              displayVal: "${_duration.toStringAsFixed(0)} cuotas",
              onChanged: (val) {
                setState(() {
                  _duration = val.toInt();
                });
              },
              isDark: isDark,
            ),
            const SizedBox(height: 32),

            // Schedule breakdown
            Text(
              Localizations.localeOf(context).languageCode == 'es' ? 'Tabla de Amortización Estimada' : 'Simulated Amortization Schedule',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            _buildAmortizationBreakdown(installmentAmount, isDark),
          ],
        ),
      ),
    );
  }

  double _calculateTotalRepayment() {
    if (_interestRate <= 0) return _principal;
    switch (_interestType) {
      case 'fixed':
        return _principal + _interestRate;
      case 'simple':
        return _principal + (_principal * (_interestRate / 100));
      case 'compound':
        return _principal * pow(1 + (_interestRate / 100), _duration);
      default:
        return _principal;
    }
  }

  Widget _buildSimulationResults(
    double totalRepayment,
    double totalProfit,
    double installmentAmount,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF1E1E3F), const Color(0xFF141428)] 
              : [theme.colorScheme.primary.withValues(alpha: 0.8), theme.colorScheme.primary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Localizations.localeOf(context).languageCode == 'es' ? 'TOTAL A PAGAR' : 'TOTAL REPAYMENT',
                    style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "\$${totalRepayment.toStringAsFixed(2)}",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Localizations.localeOf(context).languageCode == 'es' ? 'INTERÉS GANADO' : 'NET PROFIT',
                    style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "\$${totalProfit.toStringAsFixed(2)}",
                    style: GoogleFonts.outfit(
                      color: Colors.greenAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Localizations.localeOf(context).languageCode == 'es' ? 'Monto estimado de la cuota:' : 'Estimated quota amount:',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
              ),
              Text(
                "\$${installmentAmount.toStringAsFixed(2)}",
                style: GoogleFonts.outfit(
                  color: Colors.yellowAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSection({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayVal,
    required ValueChanged<double> onChanged,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141428) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                displayVal,
                style: GoogleFonts.outfit(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: theme.colorScheme.primary,
            inactiveColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInterestTypeSelector(bool isDark) {
    final theme = Theme.of(context);
    final types = [
      {'val': 'fixed', 'lbl': Localizations.localeOf(context).languageCode == 'es' ? 'Interés Fijo' : 'Fixed'},
      {'val': 'simple', 'lbl': Localizations.localeOf(context).languageCode == 'es' ? 'Porcentual' : 'Percentage'},
      {'val': 'compound', 'lbl': Localizations.localeOf(context).languageCode == 'es' ? 'Compuesto' : 'Compound'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Localizations.localeOf(context).languageCode == 'es' ? 'Tipo de Interés' : 'Interest Scheme',
          style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: types.map((t) {
            final active = _interestType == t['val'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _interestType = t['val']!;
                    if (_interestType == 'fixed' && _interestRate > 5000) {
                      _interestRate = 500;
                    } else if (_interestType != 'fixed' && _interestRate > 100) {
                      _interestRate = 10;
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: active
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF141428) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active 
                          ? theme.colorScheme.primary 
                          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.15)),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t['lbl']!,
                    style: GoogleFonts.outfit(
                      color: active ? theme.colorScheme.primary : Colors.grey,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFrequencySelector(bool isDark) {
    final theme = Theme.of(context);
    final freqs = [
      {'val': 'daily', 'lbl': Localizations.localeOf(context).languageCode == 'es' ? 'Diario' : 'Daily'},
      {'val': 'weekly', 'lbl': Localizations.localeOf(context).languageCode == 'es' ? 'Semanal' : 'Weekly'},
      {'val': 'biweekly', 'lbl': Localizations.localeOf(context).languageCode == 'es' ? 'Quincenal' : 'Biweekly'},
      {'val': 'monthly', 'lbl': Localizations.localeOf(context).languageCode == 'es' ? 'Mensual' : 'Monthly'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Localizations.localeOf(context).languageCode == 'es' ? 'Frecuencia de Pago' : 'Installment Schedule',
          style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: freqs.map((f) {
            final active = _frequency == f['val'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _frequency = f['val']!;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF141428) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active 
                          ? theme.colorScheme.primary 
                          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.15)),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    f['lbl']!,
                    style: GoogleFonts.outfit(
                      color: active ? theme.colorScheme.primary : Colors.grey,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAmortizationBreakdown(double quotaAmount, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141428) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.15)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _duration > 15 ? 15 : _duration,
        separatorBuilder: (context, idx) => Divider(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[200], height: 1),
        itemBuilder: (context, idx) {
          final count = idx + 1;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${Localizations.localeOf(context).languageCode == 'es' ? 'Cuota' : 'Quota'} #$count",
                  style: GoogleFonts.outfit(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      "\$${quotaAmount.toStringAsFixed(2)}",
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        Localizations.localeOf(context).languageCode == 'es' ? 'Simulada' : 'Simulated',
                        style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
