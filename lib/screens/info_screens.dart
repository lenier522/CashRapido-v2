import 'package:material_ui/material_ui.dart';
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
          // Primeros pasos
          _buildSectionHeader(
            context,
            '🚀 ${context.t('help_section_start')}',
          ),
          _buildHelpItem(
            context,
            context.t('help_q_add_card'),
            context.t('help_a_add_card'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_add_transaction'),
            context.t('help_a_add_transaction'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_scanner'),
            context.t('help_a_scanner'),
          ),
          const SizedBox(height: 20),

          // Prueba gratuita y planes
          _buildSectionHeader(
            context,
            '🎁 ${context.t('help_section_trial')}',
          ),
          _buildHelpItem(
            context,
            context.t('help_q_trial'),
            context.t('help_a_trial'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_trial_end'),
            context.t('help_a_trial_end'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_plans'),
            context.t('help_a_plans'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_payment'),
            context.t('help_a_payment'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_restore_purchase'),
            context.t('help_a_restore_purchase'),
          ),
          const SizedBox(height: 20),

          // Movimientos
          _buildSectionHeader(
            context,
            '💰 ${context.t('help_section_movements')}',
          ),
          _buildHelpItem(
            context,
            context.t('help_q_edit_transaction'),
            context.t('help_a_edit_transaction'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_transfer'),
            context.t('help_a_transfer'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_recurring'),
            context.t('help_a_recurring'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_categories'),
            context.t('help_a_categories'),
          ),
          const SizedBox(height: 20),

          // Cuentas y tarjetas
          _buildSectionHeader(context, '💳 ${context.t('cards')}'),
          _buildHelpItem(
            context,
            context.t('help_q_cards_limit'),
            context.t('help_a_cards_limit'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_change_balance'),
            context.t('help_a_change_balance'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_card_pin'),
            context.t('help_a_card_pin'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_money_counter'),
            context.t('help_a_money_counter'),
          ),
          const SizedBox(height: 20),

          // Estadísticas y exportación
          _buildSectionHeader(
            context,
            '📊 ${context.t('help_section_stats')}',
          ),
          _buildHelpItem(
            context,
            context.t('help_q_stats'),
            context.t('help_a_stats'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_export'),
            context.t('help_a_export'),
          ),
          const SizedBox(height: 20),

          // Copias de seguridad
          _buildSectionHeader(
            context,
            '☁️ ${context.t('help_section_backup')}',
          ),
          _buildHelpItem(
            context,
            context.t('help_q_backup_local'),
            context.t('help_a_backup_local'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_drive'),
            context.t('help_a_drive'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_delete_data'),
            context.t('help_a_delete_data'),
          ),
          const SizedBox(height: 20),

          // Negocio y préstamos
          _buildSectionHeader(
            context,
            '🏪 ${context.t('help_section_business')}',
          ),
          _buildHelpItem(
            context,
            context.t('help_q_business'),
            context.t('help_a_business'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_loans'),
            context.t('help_a_loans'),
          ),
          const SizedBox(height: 20),

          // Seguridad, IA y ajustes
          _buildSectionHeader(context, '⚙️ ${context.t('settings_title')}'),
          _buildHelpItem(
            context,
            context.t('help_q_security'),
            context.t('help_a_security'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_ai'),
            context.t('help_a_ai'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_custom_bank'),
            context.t('help_a_custom_bank'),
          ),
          _buildHelpItem(
            context,
            context.t('help_q_currency'),
            context.t('help_a_currency'),
          ),
          const SizedBox(height: 20),

          // Soporte
          _buildSectionHeader(context, '💬 ${context.t('feedback_title')}'),
          _buildHelpItem(
            context,
            context.t('help_q_feedback'),
            context.t('help_a_feedback'),
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
          fontSize: 18,
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
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              answer,
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}
