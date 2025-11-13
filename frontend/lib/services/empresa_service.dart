import 'package:registro_horario/services/api_service.dart';
import 'package:registro_horario/services/auth_service.dart';

class EmpresaService {
  static Future<List<dynamic>> getEmployees() async {
    return await ApiService.get("/empresa/empleados");
  }

  static Future<void> sendInvite(String email) async {
    final user = await AuthService.getCurrentUser();

    print("📦 Usuario autenticado:");
    print(user);

    final empresaId = user["empresa_id"] ?? user["empresa"]?["id"];
    print("📤 Enviando invitación → empresa_id: $empresaId, email: $email");

    if (empresaId == null) {
      throw Exception("No se encontró la empresa del usuario actual");
    }

    final body = {"empresa_id": empresaId, "email": email};
    print("📬 Body final: $body");

    final res = await ApiService.post("/invitaciones/enviar", body);

    print("✅ Invitación enviada correctamente: $res");
  }

  static Future<List<dynamic>> listarInvitaciones() async {
    final res = await ApiService.get("/invitaciones/");
    return List<Map<String, dynamic>>.from(res);
  }
}
