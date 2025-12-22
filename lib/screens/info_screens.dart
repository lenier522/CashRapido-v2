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
        padding: const EdgeInsets.all(20),
        children: [
          _buildHelpItem(
            context,
            "¿Cómo agrego una tarjeta?",
            "Ve a la pantalla de Billetera (icono inferior), toca el botón '+' y rellena los datos de tu tarjeta o efectivo.",
          ),
          _buildHelpItem(
            context,
            "¿Cómo uso la IA?",
            "Activa la IA en Configuración. Luego, toca el icono del robot en la pantalla principal para preguntar sobre tus gastos.",
          ),
          _buildHelpItem(
            context,
            "¿Mis datos están seguros?",
            "Sí, todos los datos se guardan en tu teléfono. Si activas la biometría, nadie podrá entrar sin tu huella o rostro.",
          ),
          _buildHelpItem(
            context,
            "¿Cómo transfiero dinero?",
            "Usa el botón 'Transferir' en la pantalla de inicio. Si es entre tus propias tarjetas, marca la casilla 'Transferencia Interna'.",
          ),
          _buildHelpItem(
            context,
            "¿Qué hago si olvido mi PIN?",
            "Por seguridad, no guardamos tu PIN. Si lo olvidas, tendrás que reinstalar la aplicación, pero podrás restaurar tu copia de seguridad si hiciste una previamente.",
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(BuildContext context, String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            answer,
            style: GoogleFonts.outfit(color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}
