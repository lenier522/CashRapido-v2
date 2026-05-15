import 'package:hive/hive.dart';

part 'notification_item.g.dart';

@HiveType(typeId: 21)
class NotificationItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String body;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    this.isRead = false,
  });
}
