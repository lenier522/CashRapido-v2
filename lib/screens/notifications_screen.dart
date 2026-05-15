import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notificaciones', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Marcar todas como leídas',
            onPressed: () {
              context.read<AppProvider>().markAllNotificationsAsRead();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Limpiar historial',
            onPressed: () {
              context.read<AppProvider>().clearNotifications();
            },
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final notifications = provider.notifications;
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes notificaciones',
                    style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: notif.isRead ? Colors.grey[200] : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    notif.isRead ? Icons.notifications_none : Icons.notifications_active,
                    color: notif.isRead ? Colors.grey : Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  notif.title,
                  style: GoogleFonts.outfit(
                    fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(notif.body),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yyyy hh:mm a').format(notif.date),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                onTap: () {
                  if (!notif.isRead) {
                    provider.markNotificationAsRead(notif.id);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
