import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/business_provider.dart';
import '../../models/closing.dart';

class ClosingsTab extends StatelessWidget {
  const ClosingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final closings = provider.closings.reversed.toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: closings.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: closings.length,
                  itemBuilder: (context, index) {
                    return _buildClosingCard(
                      context,
                      closings[index],
                      provider,
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'closing_fab',
            onPressed: () => _showGenerateClosingModal(context, provider),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.assessment_outlined),
            label: const Text('Generar Cierre'),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Colors.blueGrey[300],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin Reportes de Cierre',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Genera el primer cierre para ver estadísticas.',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildClosingCard(
    BuildContext context,
    Closing closing,
    BusinessProvider provider,
  ) {
    return Dismissible(
      key: Key(closing.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => provider.deleteClosing(closing.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: _buildPeriodIcon(context, closing.period),
            title: Text(
              closing.period.toUpperCase(),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              DateFormat('dd MMM yyyy').format(closing.endDate),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            childrenPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            children: [
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatColumn('Ventas', closing.income, Colors.green),
                  _buildStatColumn('Gastos', closing.expenses, Colors.red),
                  _buildStatColumn('Beneficio', closing.profit, Colors.blue),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodIcon(BuildContext context, String period) {
    IconData icon;
    Color color;
    switch (period.toLowerCase()) {
      case 'diario':
        icon = Icons.today;
        color = Colors.blue;
        break;
      case 'semanal':
        icon = Icons.date_range;
        color = Colors.orange;
        break;
      case 'mensual':
        icon = Icons.calendar_month;
        color = Colors.purple;
        break;
      default:
        icon = Icons.insert_chart;
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildStatColumn(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showGenerateClosingModal(
    BuildContext context,
    BusinessProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GenerateClosingSheet(provider: provider),
    );
  }
}

class _GenerateClosingSheet extends StatefulWidget {
  final BusinessProvider provider;
  const _GenerateClosingSheet({required this.provider});

  @override
  State<_GenerateClosingSheet> createState() => _GenerateClosingSheetState();
}

class _GenerateClosingSheetState extends State<_GenerateClosingSheet> {
  String _selectedPeriod = 'daily'; // daily, weekly, monthly
  Map<String, double>? _previewStats;

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  void _calculateStats() {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'daily':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'weekly':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = now;
    }

    final stats = widget.provider.calculatePeriodStats(startDate, now);
    setState(() => _previewStats = stats);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Generar Cierre',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Toggle Buttons
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildToggleOption('Diario', 'daily'),
                _buildToggleOption('Semanal', 'weekly'),
                _buildToggleOption('Mensual', 'monthly'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Preview Card
          if (_previewStats != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Vista Previa',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPreviewStat(
                        'Ingresos',
                        _previewStats!['income']!,
                        Colors.green,
                      ),
                      _buildPreviewStat(
                        'Gastos',
                        _previewStats!['expenses']!,
                        Colors.red,
                      ),
                      _buildPreviewStat(
                        'Neto',
                        _previewStats!['profit']!,
                        Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _saveClosing();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Confirmar y Guardar Reporte'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = value;
          });
          _calculateStats();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).cardColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewStat(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
      ],
    );
  }

  void _saveClosing() {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'daily':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'weekly':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = now;
    }

    String label = 'Diario';
    if (_selectedPeriod == 'weekly') label = 'Semanal';
    if (_selectedPeriod == 'monthly') label = 'Mensual';

    widget.provider.createClosing(
      period: label,
      startDate: startDate,
      endDate: now,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cierre generado correctamente'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
