import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/business_provider.dart';
import '../../models/seller.dart';
import 'seller_form_screen.dart';
import 'seller_assign_products_screen.dart';
import 'seller_detail_screen.dart';

class SellersTab extends StatelessWidget {
  const SellersTab({super.key});

  Color _colorFromName(String name) {
    final hash = name.hashCode;
    final hue = hash % 360;
    return HSVColor.fromAHSV(1, hue.toDouble(), 0.5, 0.8).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final sellers = provider.sellers;

        return Stack(
          children: [
            sellers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.badge_outlined,
                            size: 60,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No hay vendedores',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agrega vendedores para gestionar tu equipo',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: sellers.length,
                    itemBuilder: (context, index) {
                      final seller = sellers[index];
                      final color = _colorFromName(seller.fullName);
                      return _SellerCard(seller: seller, color: color);
                    },
                  ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'add_seller',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SellerFormScreen(),
                    ),
                  );
                },
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SellerCard extends StatelessWidget {
  final Seller seller;
  final Color color;

  const _SellerCard({required this.seller, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color,
          child: Text(
            _initials(seller.name, seller.lastName),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          seller.fullName,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (seller.role.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.work, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(seller.role, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(seller.phone, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                if (seller.commissionRate > 0) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.percent, size: 14, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text('${seller.commissionRate}%',
                      style: TextStyle(fontSize: 12, color: Colors.green[600])),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: seller.isActive
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                seller.isActive ? 'Activo' : 'Inactivo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: seller.isActive ? Colors.green : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 4),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'report') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SellerDetailScreen(seller: seller),
                      ),
                    );
                  } else if (value == 'inventory') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SellerAssignProductsScreen(seller: seller),
                      ),
                    );
                  } else if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SellerFormScreen(seller: seller),
                      ),
                    );
                  } else if (value == 'delete') {
                    _confirmDelete(context);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'report',
                    child: ListTile(
                      leading: Icon(Icons.assessment_outlined, size: 20),
                      title: Text('Ver Reporte'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'inventory',
                    child: ListTile(
                      leading: Icon(Icons.inventory_2_outlined, size: 20),
                      title: Text('Asignar Productos'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SellerDetailScreen(seller: seller),
            ),
          );
        },
      ),
    );
  }

  String _initials(String name, String lastName) {
    final first = name.isNotEmpty ? name[0].toUpperCase() : '';
    final second = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$second';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Vendedor'),
        content: Text('¿Eliminar a "${seller.fullName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<BusinessProvider>(context, listen: false)
                  .deleteSeller(seller.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
