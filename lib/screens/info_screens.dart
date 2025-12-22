import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/localization_service.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.t('terms'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Términos y Condiciones de Uso",
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text("""
1. Aceptación de los Términos
Al descargar o utilizar la aplicación CashRapido, usted acepta estos términos. Si no está de acuerdo, no utilice la aplicación.

2. Privacidad
Sus datos financieros se almacenan localmente en su dispositivo. Si utiliza la función de copia de seguridad en la nube, los datos se cifran antes de enviarse a su cuenta de Google Drive personal.

3. Uso de la IA
La función de Chat con IA utiliza la API de Google Gemini. Al usarla, usted acepta que las consultas se procesen a través de los servidores de Google. No envíe información confidencial como contraseñas o PINs a la IA.

4. Responsabilidad
CashRapido se proporciona "tal cual". No nos hacemos responsables de pérdidas de datos o errores en cálculos financieros. Se recomienda verificar siempre las transacciones importantes.

5. Modificaciones
Nos reservamos el derecho de modificar estos términos en cualquier momento. Las actualizaciones se reflejarán en esta pantalla.

Fecha de última actualización: 21 de Diciembre, 2025.
              """, style: GoogleFonts.outfit(fontSize: 16, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.t('help_center'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Getting Started
          _buildSectionHeader(context, '🚀 Primeros Pasos'),
          _buildHelpItem(
            context,
            "¿Cómo agregar mi primera tarjeta?",
            "Ve a la pantalla de Billetera (icono inferior), toca el botón '+' y rellena los datos de tu tarjeta o efectivo.",
          ),
          _buildHelpItem(
            context,
            "¿Cómo registrar una transacción?",
            "Toca el botón '+' flotante. Selecciona gasto/ingreso, categoría, monto y descripción.",
          ),
          _buildHelpItem(
            context,
            "¿Cómo usar el escáner?",
            "Toca 'Más' en acciones rápidas → 'Escanear Tarjeta'. Alinea tu tarjeta con el marco.",
          ),
          const SizedBox(height: 20),

          // Transactions
          _buildSectionHeader(context, '💰 Transacciones'),
          _buildHelpItem(
            context,
            "¿Cómo editar una transacción?",
            "Toca cualquier transacción en la lista para ver detalles y editarla o eliminarla.",
          ),
          _buildHelpItem(
            context,
            "¿Cómo transferir entre tarjetas?",
            "Usa 'Transferir' en acciones rápidas. Selecciona origen, destino y monto.",
          ),
          _buildHelpItem(
            context,
            "¿Puedo crear categorías personalizadas?",
            "Las categorías son predefinidas (Comida, Transporte, etc.) para simplicidad.",
          ),
          const SizedBox(height: 20),

          // Cards & Accounts
          _buildSectionHeader(context, '💳 Tarjetas'),
          _buildHelpItem(
            context,
            "¿Cuántas tarjetas puedo tener?",
            "Ilimitadas: efectivo, bancos, tarjetas de crédito, etc.",
          ),
          _buildHelpItem(
            context,
            "¿Cómo cambiar el balance?",
            "Ve a Billetera → Toca la tarjeta → Editar → Ajusta el balance.",
          ),
          _buildHelpItem(
            context,
            "¿Qué es el Contador de Dinero?",
            "Herramienta para contar billetes/monedas. Solo para cuentas de Efectivo.",
          ),
          const SizedBox(height: 20),

          // Statistics
          _buildSectionHeader(context, '📊 Estadísticas'),
          _buildHelpItem(
            context,
            "¿Cómo ver gastos por categoría?",
            "Pestaña Estadísticas muestra gráficos circulares organizados por categoría.",
          ),
          _buildHelpItem(
            context,
            "¿Puedo exportar datos?",
            "Sí, en Configuración → Exportar Datos (Excel o PDF).",
          ),
          _buildHelpItem(
            context,
            "¿Cómo cambiar el período?",
            "En Estadísticas, toca el selector: Mes, Año o Rango personalizado.",
          ),
          const SizedBox(height: 20),

          // AI Assistant
          _buildSectionHeader(context, '🤖 Asistente IA'),
          _buildHelpItem(
            context,
            "¿Qué hace la IA?",
            "Analiza gastos, da consejos financieros y responde preguntas sobre tus finanzas.",
          ),
          _buildHelpItem(
            context,
            "¿Cómo activar la IA?",
            "Configuración → Asistente IA → Activar. El botón aparecerá en inicio.",
          ),
          _buildHelpItem(
            context,
            "¿Mis datos están seguros?",
            "Sí, todos los datos se guardan en tu teléfono. Si activas la biometría, nadie podrá entrar sin tu huella o rostro.",
          ),
          const SizedBox(height: 20),

          // Settings
          _buildSectionHeader(context, '⚙️ Configuración'),
          _buildHelpItem(
            context,
            "¿Cómo cambiar idioma?",
            "Configuración → Idioma → Español/English/Français.",
          ),
          _buildHelpItem(
            context,
            "¿Cómo activar biometría?",
            "Configuración → Seguridad → Bloqueo Biométrico.",
          ),
          _buildHelpItem(
            context,
            "¿Cómo cambiar moneda?",
            "Configuración → Moneda Principal → Selecciona o crea una.",
          ),
          const SizedBox(height: 20),

          // Troubleshooting
          _buildSectionHeader(context, '🔧 Problemas'),
          _buildHelpItem(
            context,
            "No guarda mis cambios",
            "Verifica permisos de almacenamiento. Reinicia la app si persiste.",
          ),
          _buildHelpItem(
            context,
            "Escáner no detecta tarjeta",
            "Asegura buena iluminación y alineación. Algunos diseños no son detectables.",
          ),
          _buildHelpItem(
            context,
            "¿Qué hago si olvido mi PIN?",
            "Por seguridad, no guardamos tu PIN. Si lo olvidas, tendrás que reinstalar la aplicación, pero podrás restaurar tu copia de seguridad si hiciste una previamente.",
          ),
          const SizedBox(height: 20),

          // Contact
          _buildSectionHeader(context, '📧 Contacto'),
          _buildHelpItem(
            context,
            "¿Cómo reportar un error?",
            "Contacta al desarrollador con descripción detallada del problema.",
          ),
          _buildHelpItem(
            context,
            "¿Hay versión web?",
            "Actualmente solo disponible como app móvil (Android/iOS).",
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildHelpItem(BuildContext context, String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          question,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              answer,
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}
