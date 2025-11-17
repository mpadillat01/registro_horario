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

    // Intentos ordenados
    String? empresaId;

    // 1️⃣ Si viene en la raíz del token
    if (user["empresa_id"] != null &&
        user["empresa_id"].toString().isNotEmpty) {
      empresaId = user["empresa_id"].toString();
    }
    // 2️⃣ Si viene como nested object empresa { id: ... }
    else if (user["empresa"] != null && user["empresa"]["id"] != null) {
      empresaId = user["empresa"]["id"].toString();
    }
    // 3️⃣ Si viene como id en empresaData
    else if (user["empresaId"] != null) {
      empresaId = user["empresaId"].toString();
    }

    print("🏭 empresaId detectado → $empresaId");

    if (empresaId == null) {
      print("❌ ERROR → No se encontró empresa en el usuario");
      print("📝 Usuario completo:");
      print(user);
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

  static Future<Map<String, dynamic>> checkLimit() async {
    final res = await ApiService.get("/empresa/verificar-limite");
    return Map<String, dynamic>.from(res);
  }
}
