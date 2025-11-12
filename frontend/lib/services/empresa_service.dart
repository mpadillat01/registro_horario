import 'package:registro_horario/services/api_service.dart';
import 'package:registro_horario/services/auth_service.dart';

class EmpresaService {
  /// 🔹 Obtiene todos los empleados de la empresa actual
  static Future<List<dynamic>> getEmployees() async {
    return await ApiService.get("/empresa/empleados");
  }

  /// 📨 Envía una invitación a un nuevo empleado
  static Future<void> sendInvite(String email) async {
    // ✅ usa el método correcto del AuthService
    final user = await AuthService.getCurrentUser();
    final empresaId = user["empresa_id"];

    if (empresaId == null) {
      throw Exception("No se encontró la empresa del usuario actual");
    }

    await ApiService.post("/invitaciones/", {
      "empresa_id": empresaId,
      "email": email,
    });
  }

  /// 📋 Lista todas las invitaciones existentes (opcional)
  static Future<List<dynamic>> listarInvitaciones() async {
    final res = await ApiService.get("/invitaciones/");
    return List<Map<String, dynamic>>.from(res);
  }
}
