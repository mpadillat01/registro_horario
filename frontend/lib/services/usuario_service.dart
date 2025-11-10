import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class EmpleadoService {
  static Future<List<dynamic>> getEmpleados() async {
    return await ApiService.get("/usuarios/empleados");
  }

  static Future<void> invitarEmpleado(String email) async {
    await ApiService.post("/empresa/invitar", {"email": email});
  }

  static Future<List<dynamic>> getHorasEmpleado(String id) async {
    return await ApiService.get("/fichajes/empleado/$id/horas");
  }

  static Map<String, dynamic>? ultimoFichajeEstado;

  static Future<void> cargarEstadoActual(String userId) async {
    final res = await http.get(
      Uri.parse("${ApiService.baseUrl}/fichajes/ultimo/$userId"),
      headers: await ApiService.authHeaders(),
    );

    if (res.statusCode == 200 && res.body.isNotEmpty) {
      ultimoFichajeEstado = jsonDecode(res.body);
    }
  }

  /// ✅ Normalizamos el estado según la API
  static String estadoFromAPI() {
    if (ultimoFichajeEstado == null) return "fuera";

    final raw =
        (ultimoFichajeEstado!["estado"] ?? ultimoFichajeEstado!["tipo"] ?? "")
            .toString()
            .toLowerCase();

    if (raw.contains("entrada") ||
        raw.contains("in") ||
        raw.contains("start") ||
        raw == "1" ||
        raw.contains("working"))
      return "entrada";

    if (raw.contains("pausa") || raw.contains("pause") || raw.contains("break"))
      return "pausa";

    return "fuera";
  }
}
