import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/loan_provider.dart';
import '../../models/borrower.dart';
import 'borrower_form_screen.dart';

class BorrowersListScreen extends StatefulWidget {
  const BorrowersListScreen({super.key});

  @override
  State<BorrowersListScreen> createState() => _BorrowersListScreenState();
}

class _BorrowersListScreenState extends State<BorrowersListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          Localizations.localeOf(context).languageCode == 'es' ? 'Directorio de Clientes' : 'Client Directory',
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
      body: Consumer<LoanProvider>(
        builder: (context, provider, _) {
          final filtered = provider.borrowers.where((b) {
            final query = _searchQuery.toLowerCase();
            return b.name.toLowerCase().contains(query) ||
                b.lastName.toLowerCase().contains(query) ||
                b.phone.contains(query);
          }).toList();

          return Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141428) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: Localizations.localeOf(context).languageCode == 'es'
                          ? 'Buscar cliente por nombre o teléfono...'
                          : 'Search client by name or phone...',
                      hintStyle: GoogleFonts.outfit(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(context, isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final borrower = filtered[idx];
                          return _buildBorrowerCard(context, borrower, provider, isDark);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BorrowerFormScreen()),
          );
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: Text(
          Localizations.localeOf(context).languageCode == 'es' ? 'Nuevo Cliente' : 'New Client',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildBorrowerCard(
    BuildContext context,
    Borrower borrower,
    LoanProvider provider,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    Color riskColor;
    String riskLabel;
    switch (borrower.riskLevel) {
      case 'high':
        riskColor = Colors.redAccent;
        riskLabel = Localizations.localeOf(context).languageCode == 'es' ? 'Alto Riesgo' : 'High Risk';
        break;
      case 'medium':
        riskColor = Colors.orangeAccent;
        riskLabel = Localizations.localeOf(context).languageCode == 'es' ? 'Riesgo Medio' : 'Medium Risk';
        break;
      case 'low':
      default:
        riskColor = Colors.greenAccent;
        riskLabel = Localizations.localeOf(context).languageCode == 'es' ? 'Riesgo Bajo' : 'Low Risk';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141428) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showBorrowerDetails(context, borrower, provider, isDark),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Photo Avatar
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    backgroundImage: borrower.localPhotoPath != null &&
                            File(borrower.localPhotoPath!).existsSync()
                        ? FileImage(File(borrower.localPhotoPath!))
                        : null,
                    child: borrower.localPhotoPath == null ||
                            !File(borrower.localPhotoPath!).existsSync()
                        ? Text(
                            borrower.name[0].toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          borrower.fullName,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              borrower.phone,
                              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            riskLabel,
                            style: GoogleFonts.outfit(
                              color: riskColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions Icon
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            Localizations.localeOf(context).languageCode == 'es' ? 'Sin Clientes' : 'No Clients',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              Localizations.localeOf(context).languageCode == 'es'
                  ? 'Aún no has agregado ningún deudor. Registra a tus clientes para poder asociarlos a los préstamos de forma ordenada.'
                  : 'You haven\'t added any debtors yet. Register your clients to associate them with loans neatly.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBorrowerDetails(
    BuildContext context,
    Borrower borrower,
    LoanProvider provider,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final regDateStr =
        "${borrower.registrationDate.day}/${borrower.registrationDate.month}/${borrower.registrationDate.year}";

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141428) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header / Indicator
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    backgroundImage: borrower.localPhotoPath != null &&
                            File(borrower.localPhotoPath!).existsSync()
                        ? FileImage(File(borrower.localPhotoPath!))
                        : null,
                    child: borrower.localPhotoPath == null ||
                            !File(borrower.localPhotoPath!).existsSync()
                        ? Text(
                            borrower.name[0].toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          borrower.fullName,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${Localizations.localeOf(context).languageCode == 'es' ? 'Registrado el' : 'Registered on'} $regDateStr",
                          style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Fields Grid
              _buildDetailTile(context, Icons.phone_android_rounded, 
                  Localizations.localeOf(context).languageCode == 'es' ? 'Teléfono' : 'Phone', borrower.phone, isDark),
              _buildDetailTile(context, Icons.home_rounded, 
                  Localizations.localeOf(context).languageCode == 'es' ? 'Dirección' : 'Address', borrower.address, isDark),
              if (borrower.writtenLocation != null && borrower.writtenLocation!.isNotEmpty)
                _buildDetailTile(context, Icons.map_outlined, 
                    Localizations.localeOf(context).languageCode == 'es' ? 'Ubicación / Referencias escritas' : 'Written Location / References', borrower.writtenLocation!, isDark),
              if (borrower.personalReference != null && borrower.personalReference!.isNotEmpty)
                _buildDetailTile(context, Icons.people_outline, 
                    Localizations.localeOf(context).languageCode == 'es' ? 'Referencia Personal' : 'Personal Reference', borrower.personalReference!, isDark),
              if (borrower.notes != null && borrower.notes!.isNotEmpty)
                _buildDetailTile(context, Icons.notes_rounded, 
                    Localizations.localeOf(context).languageCode == 'es' ? 'Notas' : 'Notes', borrower.notes!, isDark),

              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BorrowerFormScreen(borrower: borrower),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(Localizations.localeOf(context).languageCode == 'es' ? 'Editar' : 'Edit'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.amber.withValues(alpha: 0.15),
                        foregroundColor: Colors.amberAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _confirmDeleteBorrower(context, borrower, provider),
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: Text(Localizations.localeOf(context).languageCode == 'es' ? 'Eliminar' : 'Delete'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.red.withValues(alpha: 0.15),
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTile(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBorrower(BuildContext context, Borrower borrower, LoanProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141428),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          Localizations.localeOf(context).languageCode == 'es' ? '¿Eliminar Cliente?' : 'Delete Client?',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          Localizations.localeOf(context).languageCode == 'es'
              ? '¿Estás seguro de que deseas eliminar a ${borrower.fullName}? Esto no eliminará sus préstamos existentes, pero perderás la vinculación.'
              : 'Are you sure you want to delete ${borrower.fullName}? This will not delete their existing loans, but you will lose the association.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Localizations.localeOf(context).languageCode == 'es' ? 'Cancelar' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteBorrower(borrower.id);
              if (ctx.mounted) Navigator.pop(ctx); // Close dialog
              if (context.mounted) Navigator.pop(context); // Close details sheet
            },
            child: Text(
              Localizations.localeOf(context).languageCode == 'es' ? 'Eliminar' : 'Delete',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
