import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/localization_service.dart';

class StreakCalendarScreen extends StatelessWidget {
  const StreakCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Lunes, 7 = Domingo
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14), // Hacer que coincida con el tema actual
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A14),
        elevation: 0,
        title: Text(
          context.t('streak_title'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Status
              Container(
                 padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(
                   color: Colors.orange.withValues(alpha: 0.15),
                   borderRadius: BorderRadius.circular(20),
                   border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                 ),
                 child: Column(
                   children: [
                     const Text('🔥', style: TextStyle(fontSize: 48)),
                     const SizedBox(height: 10),
                     Text(
                       context.t('streak_days').replaceAll(
                         '{count}',
                         '${provider.streakDays}',
                       ),
                       style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                     ),
                     const SizedBox(height: 5),
                     Text(
                       context.t('streak_reward_hint'),
                       style: GoogleFonts.outfit(fontSize: 14, color: Colors.orangeAccent),
                       textAlign: TextAlign.center,
                     ),
                   ],
                 )
              ),
              const SizedBox(height: 30),
              
              // Botón de recompensas (si hay disponibles)
              if (provider.availableRandomPlans > 0)
                ElevatedButton.icon(
                  onPressed: () => _showClaimDialog(context, provider),
                  icon: const Icon(Icons.card_giftcard),
                  label: Text(
                    context.t('streak_claim_button').replaceAll(
                      '{count}',
                      '${provider.availableRandomPlans}',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              if (provider.availableRandomPlans > 0) const SizedBox(height: 30),
              
              // Calendario del mes actual
              Text(
                context.t('streak_calendar_month'),
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 16),
              _buildWeekDays(context),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: daysInMonth + firstWeekday - 1,
                  itemBuilder: (context, index) {
                    if (index < firstWeekday - 1) {
                      return const SizedBox.shrink(); // Espacio en blanco antes del día 1
                    }
                    final day = index - (firstWeekday - 1) + 1;
                    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
                    final isLogged = provider.loginDates.contains(dateStr);
                    final isToday = day == now.day;
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: isLogged ? Colors.orange.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: isToday ? Border.all(color: Colors.white54) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        day.toString(),
                        style: GoogleFonts.outfit(
                          color: isLogged ? Colors.orangeAccent : Colors.white54,
                          fontWeight: isLogged ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekDays(BuildContext context) {
    final days = [
      context.t('streak_weekday_mon'),
      context.t('streak_weekday_tue'),
      context.t('streak_weekday_wed'),
      context.t('streak_weekday_thu'),
      context.t('streak_weekday_fri'),
      context.t('streak_weekday_sat'),
      context.t('streak_weekday_sun'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days.map((d) => 
        Text(d, style: GoogleFonts.outfit(color: Colors.white54, fontWeight: FontWeight.bold))
      ).toList(),
    );
  }

  void _showClaimDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141428),
        title: Text('🎁 ${context.t('streak_reward_title')}', style: GoogleFonts.outfit(color: Colors.white)),
        content: Text(
          context.t('streak_reward_question').replaceAll(
            '{count}',
            '${provider.availableRandomPlans}',
          ),
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel'), style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.claimRandomPlan();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🎉 ${context.t('streak_reward_success')}', style: GoogleFonts.outfit()),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: Text(context.t('streak_claim'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }
}
