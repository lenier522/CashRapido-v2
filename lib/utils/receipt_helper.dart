import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/sale.dart';
import '../../models/business.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

class ReceiptHelper {
  static Future<void> shareReceipt(BuildContext context, Sale sale, Business business) async {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    
    final StringBuffer sb = StringBuffer();
    sb.writeln('================================');
    sb.writeln('       ${business.name.toUpperCase()}');
    sb.writeln('================================');
    sb.writeln('Fecha: ${dateFormat.format(sale.date)}');
    sb.writeln('Recibo: ${sale.id.substring(0, 8).toUpperCase()}');
    if (sale.clientName != null) {
      sb.writeln('Cliente: ${sale.clientName}');
    }
    if (sale.sellerName != null && sale.sellerName!.isNotEmpty) {
      sb.writeln('Vendedor: ${sale.sellerName}');
    }
    sb.writeln('--------------------------------');
    
    for (var item in sale.items) {
      sb.writeln(item.productName);
      sb.writeln('${item.quantity} x \$${item.unitPrice.toFormattedString(2)} = \$${item.subtotal.toFormattedString(2)}');
    }
    sb.writeln('--------------------------------');
    
    final subtotal = sale.total + sale.discount;
    sb.writeln('Subtotal: \$${subtotal.toFormattedString(2)}');
    
    if (sale.discount > 0) {
      sb.writeln('Descuento: -\$${sale.discount.toFormattedString(2)}');
    }
    
    sb.writeln('TOTAL: \$${sale.total.toFormattedString(2)}');
    sb.writeln('--------------------------------');
    sb.writeln('Método: ${sale.paymentMethod}');
    sb.writeln('Estado: ${sale.status == 'paid' ? 'PAGADO' : 'PENDIENTE (CRÉDITO)'}');
    sb.writeln('================================');
    sb.writeln('   ¡Gracias por su compra!   ');
    sb.writeln('================================');

    await Share.share(sb.toString(), subject: 'Recibo de Compra - ${business.name}');
  }
}
