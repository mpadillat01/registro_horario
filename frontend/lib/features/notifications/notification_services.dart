import 'package:registro_horario/services/api_service.dart';

class NotificationsService {
  // ✅ Obtiene las notificaciones reales del backend
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final res = await ApiService.get("/notificaciones/me");
    return List<Map<String, dynamic>>.from(res);
  }

  // ✅ Marca todas como leídas
  static Future<void> markAllRead() async {
    await ApiService.post("/notificaciones/mark_all", {});
  }

  // ✅ Elimina una notificación
  static Future<void> deleteNotification(String id) async {
    await ApiService.post("/notificaciones/delete/$id", {});
  }
}
