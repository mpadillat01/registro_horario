import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'storage/storage_provider.dart';

class AuthService {
  // 🔹 Guarda el token de sesión
  static Future<void> _saveToken(String token) async {
    await storage.saveToken(token);
  }

  // 🔹 Login de usuario
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final res = await ApiService.post("/auth/login", {
      "email": email,
      "password": password,
    });

    // ✅ guarda correctamente el access_token
    await _saveToken(res["access_token"]);
    await Future.delayed(const Duration(milliseconds: 50));

    final user = await ApiService.get("/auth/me");
    return {"token": res["access_token"], "user": user};
  }

  // 🔹 Registro de empresa (admin principal)
  static Future<bool> registerCompany(
    String empresa,
    String admin,
    String email,
    String password,
  ) async {
    final res = await ApiService.post("/auth/register_empresa", {
      "nombre": empresa,
      "nombre_admin": admin,
      "email_admin": email,
      "password": password,
      "max_empleados": 10,
    });

    await _saveToken(res["token"]);
    return true;
  }

  // 🔹 Obtener usuario autenticado actual
  static Future<Map<String, dynamic>> getCurrentUser() async {
    final token = await storage.getToken();
    if (token == null) throw Exception("No token stored");

    return await ApiService.get("/auth/me");
  }

  // 🔹 Cerrar sesión
  static Future<void> logout() async {
    await storage.deleteToken();
  }

  // 🔹 Asignar plan a empresa
  static Future<void> setCompanyPlan(String planName) async {
    final baseUrl = ApiService.baseUrl;
    final url = Uri.parse("$baseUrl/empresa/plan");
    final headers = await ApiService.authHeaders();

    final res = await http.post(
      url,
      headers: headers,
      body: jsonEncode({"plan": planName}),
    );

    if (res.statusCode >= 400) {
      throw Exception("Error al actualizar el plan");
    }
  }

  // 🔹 Enviar mensaje a los empleados (admin)
  static Future<void> sendMessageToEmployees({
    required String titulo,
    required String mensaje,
    bool todos = true,
    String? usuarioId,
  }) async {
    final baseUrl = ApiService.baseUrl;
    final url = Uri.parse("$baseUrl/notificaciones/enviar");
    final headers = await ApiService.authHeaders();

    final body = {
      "titulo": titulo,
      "mensaje": mensaje,
      "tipo": "mensaje_admin",
      "origen": "admin",
      "todos": todos,
    };

    if (!todos && usuarioId != null) body["usuario_id"] = usuarioId;

    final res = await http.post(url, headers: headers, body: jsonEncode(body));

    if (res.statusCode >= 400) {
      throw Exception("Error al enviar mensaje: ${res.body}");
    }
  }

  static Future<List<Map<String, dynamic>>> getEmployees() async {
    final res = await ApiService.get("/usuarios/empleados");
    return List<Map<String, dynamic>>.from(res);
  }
}
