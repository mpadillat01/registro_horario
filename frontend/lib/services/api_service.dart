import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'storage/storage_provider.dart';

class ApiService {
  // ✅ Ajuste automático según plataforma
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:8000"; // navegador web
    }
    if (Platform.isAndroid) {
      return "http://10.0.2.2:8000"; // emulador Android
    }
    if (Platform.isIOS) {
      return "http://127.0.0.1:8000"; // simulador iOS
    }
    // ✅ Si es dispositivo físico o app desktop (Windows/Mac/Linux)
    return "http://192.168.1.X:8000"; // ⬅️ cambia por la IP local de tu PC
  }

  // ------------------------
  // 🔐 Token + headers
  // ------------------------
  static Future<Map<String, String>> authHeaders() async {
    final token = await storage.getToken();
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  // ------------------------
  // 🌍 Métodos HTTP
  // ------------------------
  static Future<dynamic> get(String endpoint) async {
    final uri = Uri.parse("$baseUrl$endpoint");
    try {
      final res = await http.get(uri, headers: await authHeaders());
      return _handleResponse(res);
    } catch (e) {
      print("❌ Error GET $uri → $e");
      throw Exception("Error de conexión al servidor");
    }
  }

  static Future<dynamic> post(String endpoint, dynamic data) async {
    final uri = Uri.parse("$baseUrl$endpoint");
    try {
      final res = await http.post(uri,
          headers: await authHeaders(), body: jsonEncode(data));
      return _handleResponse(res);
    } catch (e) {
      print("❌ Error POST $uri → $e");
      throw Exception("Error de conexión al servidor");
    }
  }

  // ------------------------
  // ⚙️ Manejo de respuestas
  // ------------------------
  static dynamic _handleResponse(http.Response res) {
    print("📡 [${res.statusCode}] ${res.request?.url}");
    if (res.statusCode == 401) {
      storage.deleteToken();
      throw Exception("Sesión expirada. Inicia sesión de nuevo.");
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    try {
      final error = jsonDecode(res.body);
      throw Exception(error["detail"] ?? "Error desconocido (${res.statusCode})");
    } catch (_) {
      throw Exception("Error HTTP ${res.statusCode}");
    }
  }
}
