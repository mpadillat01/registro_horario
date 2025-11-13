import 'package:registro_horario/services/api_service.dart';

class NotificationsService {
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final res = await ApiService.get("/notificaciones/me");
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getSentNotifications() async {
    final res = await ApiService.get("/notificaciones/enviadas");
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> markAllRead() async {
    await ApiService.post("/notificaciones/mark_all", {});
  }

  static Future<void> deleteNotification(String id) async {
    await ApiService.delete("/notificaciones/$id");
  }
}
